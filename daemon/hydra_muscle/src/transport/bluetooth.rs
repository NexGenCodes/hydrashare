use std::io::{self, Read, Write};

pub struct BluetoothStream {
    #[cfg(windows)]
    socket: SOCKET,
    #[cfg(unix)]
    _dummy: (),
}

impl BluetoothStream {
    #[cfg(windows)]
    pub fn connect(addr: u64, port: u32) -> io::Result<Self> {
        unsafe {
            let socket = socket(AF_BTH as i32, SOCK_STREAM as i32, BTHPROTO_RFCOMM as i32);
            if socket == INVALID_SOCKET {
                return Err(io::Error::last_os_error());
            }

            let sockaddr = SOCKADDR_BTH {
                addressFamily: AF_BTH,
                btAddr: addr,
                serviceClassId: [0u8; 16],
                port,
            };

            let res = connect(socket, &sockaddr as *const _ as *const _, std::mem::size_of::<SOCKADDR_BTH>() as i32);
            if res == SOCKET_ERROR {
                let err = io::Error::last_os_error();
                closesocket(socket);
                return Err(err);
            }

            Ok(Self { socket })
        }
    }

    #[cfg(unix)]
    pub fn connect(_addr: u64, _port: u32) -> io::Result<Self> {
        Err(io::Error::new(io::ErrorKind::Unsupported, "Bluetooth not yet supported on this platform"))
    }
}

pub struct BluetoothListener {
    #[cfg(windows)]
    socket: SOCKET,
    #[cfg(unix)]
    _dummy: (),
}

impl BluetoothListener {
    #[cfg(windows)]
    pub fn bind(port: u32) -> io::Result<Self> {
        unsafe {
            let socket = socket(AF_BTH as i32, SOCK_STREAM as i32, BTHPROTO_RFCOMM as i32);
            if socket == INVALID_SOCKET {
                return Err(io::Error::last_os_error());
            }

            let sockaddr = SOCKADDR_BTH {
                addressFamily: AF_BTH,
                btAddr: 0, // Inaddr_any equivalent for Bluetooth
                serviceClassId: [0u8; 16],
                port,
            };

            if bind(socket, &sockaddr as *const _ as *const _, std::mem::size_of::<SOCKADDR_BTH>() as i32) == SOCKET_ERROR {
                let err = io::Error::last_os_error();
                closesocket(socket);
                return Err(err);
            }

            if listen(socket, 5) == SOCKET_ERROR {
                let err = io::Error::last_os_error();
                closesocket(socket);
                return Err(err);
            }

            Ok(Self { socket })
        }
    }

    #[cfg(windows)]
    pub fn accept(&self) -> io::Result<(BluetoothStream, u64)> {
        unsafe {
            let mut addr = std::mem::zeroed::<SOCKADDR_BTH>();
            let mut addr_len = std::mem::size_of::<SOCKADDR_BTH>() as i32;
            let client_sock = accept(self.socket, &mut addr as *mut _ as *mut _, &mut addr_len);
            
            if client_sock == INVALID_SOCKET {
                return Err(io::Error::last_os_error());
            }

            Ok((BluetoothStream { socket: client_sock }, addr.btAddr))
        }
    }

    #[cfg(unix)]
    pub fn bind(_port: u32) -> io::Result<Self> {
        Err(io::Error::new(io::ErrorKind::Unsupported, "Bluetooth not supported"))
    }

    #[cfg(unix)]
    pub fn accept(&self) -> io::Result<(BluetoothStream, u64)> {
        Err(io::Error::new(io::ErrorKind::Unsupported, "Bluetooth not supported"))
    }
}

#[cfg(windows)]
impl Drop for BluetoothListener {
    fn drop(&mut self) {
        unsafe { closesocket(self.socket); }
    }
}

// Implement Read/Write for BluetoothStream
impl Read for BluetoothStream {
    fn read(&mut self, buf: &mut [u8]) -> io::Result<usize> {
        #[cfg(windows)]
        unsafe {
            let res = recv(self.socket, buf.as_mut_ptr(), buf.len() as i32, 0);
            if res == SOCKET_ERROR {
                Err(io::Error::last_os_error())
            } else {
                Ok(res as usize)
            }
        }
        #[cfg(unix)]
        { let _ = buf; Err(io::Error::new(io::ErrorKind::Unsupported, "Bluetooth not yet supported")) }
    }
}

impl Write for BluetoothStream {
    fn write(&mut self, buf: &[u8]) -> io::Result<usize> {
        #[cfg(windows)]
        unsafe {
            let res = send(self.socket, buf.as_ptr(), buf.len() as i32, 0);
            if res == SOCKET_ERROR {
                Err(io::Error::last_os_error())
            } else {
                Ok(res as usize)
            }
        }
        #[cfg(unix)]
        { let _ = buf; Err(io::Error::new(io::ErrorKind::Unsupported, "Bluetooth not yet supported")) }
    }

    fn flush(&mut self) -> io::Result<()> {
        Ok(())
    }
}

#[cfg(windows)]
impl Drop for BluetoothStream {
    fn drop(&mut self) {
        unsafe { closesocket(self.socket); }
    }
}

#[cfg(windows)]
use windows_sys::Win32::Networking::WinSock::*;

#[cfg(windows)]
const AF_BTH: u16 = 32;
#[cfg(windows)]
const BTHPROTO_RFCOMM: i32 = 3;

#[cfg(windows)]
#[repr(C)]
#[allow(non_snake_case)]
struct SOCKADDR_BTH {
    addressFamily: u16,
    btAddr: u64,
    serviceClassId: [u8; 16], // Simplified GUID
    port: u32,
}
