import Metal

extension MTLPixelFormat {

    // MTLPixelFormatRGB10A8_2P_XR10
    static var rgba10_xr: Self? {
        .init(rawValue: 550)
    }

    // MTLPixelFormatRGB10A8_2P_XR10_sRGB
    static var rgba10_xr_srgb: Self? {
        .init(rawValue: 551)
    }
}
