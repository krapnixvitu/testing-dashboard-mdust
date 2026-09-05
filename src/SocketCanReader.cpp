#include "SocketCanReader.h"

#include "BmsDecoder.h"
#include "VehicleData.h"
#include "WaveSculptorDecoder.h"

#include <QSocketNotifier>

#ifdef Q_OS_LINUX
#include <cerrno>
#include <cstring>

#include <linux/can.h>
#include <linux/can/raw.h>
#include <net/if.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <unistd.h>
#endif

SocketCanReader::SocketCanReader(VehicleData *data, QObject *parent)
    : QObject(parent)
    , m_data(data)
{
}

SocketCanReader::~SocketCanReader()
{
    close();
}

bool SocketCanReader::isSupportedOnThisPlatform()
{
#ifdef Q_OS_LINUX
    return true;
#else
    return false;
#endif
}

#ifdef Q_OS_LINUX

bool SocketCanReader::open(const QString &interfaceName)
{
    close();

    m_fd = ::socket(PF_CAN, SOCK_RAW, CAN_RAW);
    if (m_fd < 0) {
        m_lastError = QStringLiteral("socket(PF_CAN) failed: %1").arg(QString::fromLocal8Bit(strerror(errno)));
        return false;
    }

    struct ifreq ifr;
    std::memset(&ifr, 0, sizeof(ifr));
    const QByteArray ifname = interfaceName.toLocal8Bit();
    std::strncpy(ifr.ifr_name, ifname.constData(), IFNAMSIZ - 1);

    if (::ioctl(m_fd, SIOCGIFINDEX, &ifr) < 0) {
        m_lastError = QStringLiteral("interface '%1' not found: %2")
                          .arg(interfaceName, QString::fromLocal8Bit(strerror(errno)));
        close();
        return false;
    }

    // Kernel-level filter: only motor controller broadcasts (standard 11-bit
    // 0x400-0x41F), driver controls frames (standard 0x500-0x51F) and the BMS
    // (EXTENDED 29-bit 0x100-0x107) wake this process. Everything else is
    // dropped by the kernel before it reaches us.
    //
    // When adding a new message, check its ID falls inside one of these ranges
    // AND that its frame format matches. Outside them the frame never arrives
    // here even though candump still shows it, because candump opens its own
    // unfiltered socket.
    //
    // can_id here is not just the identifier: bit 31 (CAN_EFF_FLAG) says whether
    // the frame is extended. Including that bit in the mask is what makes an
    // entry format-specific -- without it a 29-bit frame sharing the low bits
    // would match a standard entry and be handed to the wrong decoder.
    struct can_filter filters[3];
    filters[0].can_id = ws22::kMotorControllerBase;
    filters[0].can_mask = CAN_EFF_FLAG | (CAN_SFF_MASK & ~0x1Fu);
    filters[1].can_id = ws22::kDriverControlsBase;
    filters[1].can_mask = CAN_EFF_FLAG | (CAN_SFF_MASK & ~0x1Fu);
    // The BMS identifiers are sequential rather than a device/message split, so
    // masking the low 3 bits is the tightest window covering 0x100-0x107.
    filters[2].can_id = bms::kIdRangeFirst | CAN_EFF_FLAG;
    filters[2].can_mask = CAN_EFF_FLAG | (CAN_EFF_MASK & ~0x7u);
    if (::setsockopt(m_fd, SOL_CAN_RAW, CAN_RAW_FILTER, filters, sizeof(filters)) < 0) {
        m_lastError = QStringLiteral("setsockopt(CAN_RAW_FILTER) failed: %1")
                          .arg(QString::fromLocal8Bit(strerror(errno)));
        close();
        return false;
    }

    struct sockaddr_can addr;
    std::memset(&addr, 0, sizeof(addr));
    addr.can_family = AF_CAN;
    addr.can_ifindex = ifr.ifr_ifindex;

    if (::bind(m_fd, reinterpret_cast<struct sockaddr *>(&addr), sizeof(addr)) < 0) {
        m_lastError = QStringLiteral("bind to '%1' failed: %2")
                          .arg(interfaceName, QString::fromLocal8Bit(strerror(errno)));
        close();
        return false;
    }

    m_notifier = new QSocketNotifier(m_fd, QSocketNotifier::Read, this);
    connect(m_notifier, &QSocketNotifier::activated, this, &SocketCanReader::onReadyRead);

    m_lastError.clear();
    return true;
}

void SocketCanReader::onReadyRead()
{
    // The notifier only fires when data is already buffered, so this read
    // cannot block. Drain in a loop: several frames may have arrived together.
    for (;;) {
        struct can_frame frame;
        const ssize_t n = ::read(m_fd, &frame, sizeof(frame));

        if (n < 0) {
            if (errno == EINTR)
                continue;
            // EAGAIN/EWOULDBLOCK simply means the buffer is drained.
            break;
        }

        if (n != static_cast<ssize_t>(sizeof(frame)))
            continue;

        // Error frames are bus diagnostics, not data; the watchdog handles
        // liveness so they are ignored here.
        if (frame.can_id & CAN_ERR_FLAG)
            continue;

        if (frame.can_dlc < 8)
            continue;

        if (!m_data)
            continue;

        // Route on frame format, not just on the identifier. The BMS uses
        // extended IDs and big-endian payloads; the motor controller uses
        // standard IDs and little-endian ones, so handing a frame to the wrong
        // decoder produces plausible nonsense rather than an error.
        if (frame.can_id & CAN_EFF_FLAG) {
            const uint32_t id = frame.can_id & CAN_EFF_MASK;
            m_data->applyDecodedBmsFrame(bms::decode(id, frame.data));
        } else {
            const uint32_t id = frame.can_id & CAN_SFF_MASK;
            m_data->applyDecodedFrame(ws22::decode(id, frame.data));
        }
    }
}

void SocketCanReader::close()
{
    if (m_notifier) {
        m_notifier->setEnabled(false);
        m_notifier->deleteLater();
        m_notifier = nullptr;
    }
    if (m_fd >= 0) {
        ::close(m_fd);
        m_fd = -1;
    }
}

#else // !Q_OS_LINUX

bool SocketCanReader::open(const QString &interfaceName)
{
    Q_UNUSED(interfaceName)
    m_lastError = QStringLiteral("SocketCAN is only available on Linux");
    return false;
}

void SocketCanReader::onReadyRead()
{
}

void SocketCanReader::close()
{
    m_fd = -1;
}

#endif // Q_OS_LINUX
