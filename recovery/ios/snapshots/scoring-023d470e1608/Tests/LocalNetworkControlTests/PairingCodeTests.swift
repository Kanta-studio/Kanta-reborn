import Testing
@testable import LocalNetworkControl

@Test func pairingCodeRequiresExactlySixDigits() {
    #expect(PairingCode("123456")?.value == "123456")
    #expect(PairingCode("000042")?.value == "000042")
    #expect(PairingCode("12345") == nil)
    #expect(PairingCode("1234567") == nil)
    #expect(PairingCode("12A456") == nil)
}

@Test func pairingCodeFormatsNumericBootstrapWithLeadingZeros() {
    #expect(PairingCode(number: 42)?.value == "000042")
    #expect(PairingCode(number: 999_999)?.value == "999999")
    #expect(PairingCode(number: -1) == nil)
    #expect(PairingCode(number: 1_000_000) == nil)
}

