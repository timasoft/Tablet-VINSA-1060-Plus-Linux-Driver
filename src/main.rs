mod physical_device;
mod virtual_device;

use rusb::Error as RusbError;
use signal_hook::consts::signal::*;
use signal_hook::flag::register;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;

use physical_device::PhysicalDevice;
use virtual_device::{DeviceDispatcher, RawDataReader};

const VID: u16 = 0x08f2;
const PID: u16 = 0x6811;

fn main() {
    let mut physical_device = PhysicalDevice::new(VID, PID);
    physical_device.init().set_full_mode();

    let mut data_reader = RawDataReader::new();
    let mut device_dispatcher = DeviceDispatcher::new();

    println!("Driver is running.");
    main_loop(
        || match physical_device.read_device_responses(&mut data_reader.data) {
            Ok(0) => std::thread::sleep(Duration::from_millis(1)),
            Ok(_) => {
                device_dispatcher.dispatch(&data_reader);
                if device_dispatcher.syn().is_err() {
                    println!("Error emitting SYN.");
                }
            }
            Err(RusbError::Timeout | RusbError::Interrupted) => {}
            Err(error) => {
                eprintln!("Read error: {error}.");
                std::thread::sleep(Duration::from_secs(1));
            }
        },
    );
}

fn main_loop(mut f: impl FnMut()) {
    let signals: Vec<i32> = vec![SIGINT, SIGTERM, SIGQUIT];
    let flag = Arc::new(AtomicBool::new(false));

    for signal in signals {
        register(signal, Arc::clone(&flag)).expect("Error registering interrupt signals.");
    }

    while !flag.load(Ordering::Relaxed) {
        f();
    }
    println!();
    println!("The driver has exited.")
}
