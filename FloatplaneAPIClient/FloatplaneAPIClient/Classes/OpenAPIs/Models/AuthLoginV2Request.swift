//
// AuthLoginV2Request.swift
//
// Generated by openapi-generator
// https://openapi-generator.tech
//

import Foundation
#if canImport(AnyCodable)
import AnyCodable
#endif
import Vapor

public struct AuthLoginV2Request: Content, Hashable {

    public var username: String
    public var password: String
    /** The Google Recaptcha v2/v3 token to verify the request. On web browsers, this is required. For mobile or TV applications, this is not required only if the User-Agent indicates so (e.g., if the User-Agent contains \"CFNetwork\" in its value). Otherwise, the application would have to supply a valid captcha token, which can be difficult to obtain dynamically in some scenarios. */
    public var captchaToken: String?

    public init(username: String, password: String, captchaToken: String?) {
        self.username = username
        self.password = password
        self.captchaToken = captchaToken
    }

    public enum CodingKeys: String, CodingKey, CaseIterable {
        case username
        case password
        case captchaToken
    }

    // Encodable protocol methods

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(username, forKey: .username)
        try container.encode(password, forKey: .password)
        try container.encode(captchaToken, forKey: .captchaToken)
    }
}

