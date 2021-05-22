#[cfg(test)]
mod tests {
    #[test]
    fn it_works() {
        assert_eq!(2 + 2, 4);
    }
}

#[allow(dead_code)]
#[no_mangle]
pub extern "C" fn bar(a: u32) -> u32 {
    // this can be called from Objective-C
    println!("somebody called bar()");
    return a + 3;
}
