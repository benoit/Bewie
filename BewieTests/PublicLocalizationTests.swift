import XCTest
import UIKit
@testable import Bewie

final class PublicLocalizationTests: XCTestCase {
    private let languages = ["fr", "en", "en-GB", "es", "es-MX", "de", "it", "pt-BR", "ja"]
    private func resources(_ language: String) throws -> Bundle {
        try XCTUnwrap(Bundle(path: XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))))
    }

    func testEveryPublicKeyExistsInAllLanguages() throws {
        for language in languages {
            let bundle = try resources(language)
            for key in PublicText.allCases {
                let value = key.localized(in: bundle)
                XCTAssertNotEqual(value, key.rawValue, "Missing \(language): \(key.rawValue)")
                XCTAssertFalse(value.isEmpty)
            }
            let path = try XCTUnwrap(bundle.path(forResource: "Public", ofType: "strings"))
            let table = try XCTUnwrap(NSDictionary(contentsOfFile: path) as? [String: String])
            XCTAssertEqual(Set(table.keys), Set(PublicText.allCases.map(\.rawValue)))
        }
    }

    func testLanguageAndRegionalPreferencesResolveToTheirResources() {
        let available = Bundle.main.localizations
        XCTAssertEqual(Bundle.preferredLocalizations(from: available, forPreferences: ["en-US"]).first, "en")
        XCTAssertEqual(Bundle.preferredLocalizations(from: available, forPreferences: ["fr-FR"]).first, "fr")
        for (preference, resource) in [("en-GB", "en-GB"), ("es-ES", "es"), ("es-MX", "es-MX"), ("de-DE", "de"),
                                       ("it-IT", "it"), ("pt-BR", "pt-BR"), ("ja-JP", "ja")] {
            XCTAssertEqual(Bundle.preferredLocalizations(from: available, forPreferences: [preference]).first,
                           resource, preference)
        }
        XCTAssertEqual(Bundle.main.developmentLocalization, "en")
    }

    func testTranslationsAndDynamicTrackNames() throws {
        let en = try resources("en")
        let fr = try resources("fr")
        XCTAssertEqual(PublicText.resume.localized(in: en), "Resume")
        XCTAssertEqual(PublicText.resume.localized(in: fr), "Reprendre")
        XCTAssertEqual(PublicText.close.localized(in: en), "Close")
        XCTAssertEqual(PublicText.close.localized(in: fr), "Fermer")
        for language in languages {
            let bundle = try resources(language)
            for track in AlbumTrack.all {
                XCTAssertEqual(String(format: PublicText.trackLabel.localized(in: bundle), track.id, track.title), "\(track.id), \(track.title)")
                for key in [PublicText.audioUnavailable, .downloadFailed] {
                    let message = String(format: key.localized(in: bundle), track.title)
                    XCTAssertTrue(message.contains(track.title))
                    XCTAssertFalse(message.contains("%@"))
                }
            }
            XCTAssertTrue(String(format: PublicText.coordinates.localized(in: bundle), "43.482428° N").contains("43.482428° N"))
        }
    }

    func testLocationPermissionAndMacCreditsAreLocalized() throws {
        let phrases = ["fr": "Neuf morceaux. Neuf lieux.", "en": "Nine tracks. Nine places.", "en-GB": "Nine tracks. Nine places.",
                       "es": "Nueve canciones. Nueve lugares.", "es-MX": "Nueve canciones. Nueve lugares.",
                       "de": "Neun Titel. Neun Orte.", "it": "Nove brani. Nove luoghi.",
                       "pt-BR": "Nove faixas. Nove lugares.", "ja": "9曲。9つの場所。"]
        for language in languages {
            let bundle = try resources(language)
            let permission = bundle.localizedString(forKey: "NSLocationWhenInUseUsageDescription", value: nil, table: "InfoPlist")
            XCTAssertNotEqual(permission, "NSLocationWhenInUseUsageDescription", language)
            #if targetEnvironment(macCatalyst)
            XCTAssertFalse(permission.contains(language == "de" ? "WLAN" : "Wi-Fi"), language)
            XCTAssertEqual(permission, bundle.localizedString(forKey: "NSLocationUsageDescription", value: nil, table: "InfoPlist"), language)
            #else
            XCTAssertFalse(permission.contains(language == "de" ? "WLAN" : "Wi-Fi"), language)
            #endif
            XCTAssertTrue(permission.contains(language == "ja" ? "ノートルダム" : "Notre-Dame"), language)
            let url = try XCTUnwrap(bundle.url(forResource: "Credits", withExtension: "rtf"))
            // Decode actual RTF so accents and Japanese Unicode escapes are tested too.
            let credits = try NSAttributedString(data: Data(contentsOf: url),
                                                 options: [.documentType: NSAttributedString.DocumentType.rtf],
                                                 documentAttributes: nil).string
            XCTAssertTrue(credits.contains(try XCTUnwrap(phrases[language])), language)
            XCTAssertTrue(credits.contains("Benoit Cazenave"), language)
        }
    }

    func testSpanishVariantsHaveIndependentCopy() throws {
        let spain = try resources("es")
        let mexico = try resources("es-MX")
        XCTAssertEqual(PublicText.retry.localized(in: spain), "Reintentar")
        XCTAssertEqual(PublicText.retry.localized(in: mexico), "Volver a intentar")
        XCTAssertNotEqual(PublicText.downloadFailed.localized(in: spain),
                          PublicText.downloadFailed.localized(in: mexico))
    }

}
