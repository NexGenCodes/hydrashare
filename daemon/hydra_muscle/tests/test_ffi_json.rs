use std::ffi::CString;
use hydra_muscle::send_command_json;

#[test]
fn test_ffi_json_command_valid() {
    let cmd = r#"{"type": "INIT", "data_dir": "./test_data"}"#;
    let c_str = CString::new(cmd).unwrap();
    unsafe {
        let result = send_command_json(c_str.as_ptr());
        assert_eq!(result, 0, "Valid command should return 0");
    }
}

#[test]
fn test_ffi_json_command_invalid_json() {
    let cmd = r#"{"type": "INIT", "broken_json"#;
    let c_str = CString::new(cmd).unwrap();
    unsafe {
        let result = send_command_json(c_str.as_ptr());
        assert_eq!(result, -2, "Invalid JSON should return -2");
    }
}

#[test]
fn test_ffi_json_command_unknown_type() {
    // This might fail deserialization or return error depending on enum handling
    let cmd = r#"{"type": "UNKNOWN_COMMAND"}"#;
    let c_str = CString::new(cmd).unwrap();
    unsafe {
        let result = send_command_json(c_str.as_ptr());
        // Deserialization error expected
        assert_eq!(result, -2);
    }
}
