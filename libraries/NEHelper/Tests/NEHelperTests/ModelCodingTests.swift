//
//  Created on 2022-12-13.
//
//  Copyright (c) 2022 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import XCTest
@testable import NEHelper

final class ModelCodingTests: XCTestCase {

    
    func testServerStatusResponseDecoding() throws {
        let data = alternativesJson.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let model = try decoder.decode(ServerStatusRequest.Response.self, from: data)
        XCTAssertEqual(model.code, 1000)
        XCTAssertEqual(model.original.status, 1)
    }

}

private let alternativesJson = """
{
    "Code": 1000,
    "Original": {
        "Name": "IS1",
        "EntryCountry": "IS",
        "ExitCountry": "IS",
        "Domain": "node-is-01.protonvpn.net",
        "Tier": 0,
        "Features": 0,
        "Region": null,
        "City": null,
        "Score": 3,
        "HostCountry": null,
        "ID": "YC6ClO",
        "Location": {
            "Lat": 0,
            "Long": 0
        },
        "Status": 1,
        "Servers": [
            {
                "EntryIP": "185.159.158.1",
                "ExitIP": "185.159.158.100",
                "Domain": "node-is-001.protonvpn.net",
                "ID": "FHNF",
                "Label": "2",
                "X25519PublicKey": "yKbYe2XwbeNN9CuPZcwMF/lJp6a62NEGiHCCfpfxrnE=",
                "Generation": 0,
                "Status": 1,
                "ServicesDown": 0,
                "ServicesDownReason": null
            }
        ],
        "Load": 0
    },
    "Alternatives": [
        {
            "Name": "IS3",
            "EntryCountry": "IS",
            "ExitCountry": "IS",
            "Domain": "node-is-01.protonvpn.net",
            "Tier": 0,
            "Features": 0,
            "Region": null,
            "City": null,
            "Score": 3,
            "HostCountry": null,
            "ID": "VcYju",
            "Location": {
                "Lat": 0,
                "Long": 0
            },
            "Status": 1,
            "Servers": [
                {
                    "EntryIP": "185.159.158.1",
                    "ExitIP": "185.159.158.101",
                    "Domain": "node-is-003.protonvpn.net",
                    "ID": "dTqmn",
                    "Label": "3",
                    "X25519PublicKey": "yKbYe2XwbeNN9CuPZcwMF/lJp6a62NEGiHCCfpfxrnE=",
                    "Generation": 0,
                    "Status": 1,
                    "ServicesDown": 0,
                    "ServicesDownReason": null,
                    "EntryPerProtocol": {
                        "WireGuardTLS": {
                            "IPv4": "1.1.1.2"
                        }
                    }
                }
            ],
            "Load": 0
        },
        {
            "Name": "NL-FREE#2",
            "EntryCountry": "NL",
            "ExitCountry": "NL",
            "Domain": "nl-free-02.protonvpn.com",
            "Tier": 0,
            "Features": 0,
            "Region": null,
            "City": null,
            "Score": 3.7000000000000002,
            "HostCountry": null,
            "ID": "GsNU4F",
            "Location": {
                "Lat": 52.369999999999997,
                "Long": 4.8899999999999997
            },
            "Status": 0,
            "Servers": [
                {
                    "EntryIP": "217.23.3.171",
                    "ExitIP": "217.23.3.171",
                    "Domain": "nl-104.protonvpn.com",
                    "ID": "KV8mjIm",
                    "Label": "",
                    "X25519PublicKey": null,
                    "Generation": 0,
                    "Status": 0,
                    "ServicesDown": 0,
                    "ServicesDownReason": null
                },
                {
                    "EntryIP": "89.39.107.205",
                    "ExitIP": "89.39.107.205",
                    "Domain": "nl-108.protonvpn.com",
                    "ID": "pcCWuJ",
                    "Label": "",
                    "X25519PublicKey": null,
                    "Generation": 0,
                    "Status": 0,
                    "ServicesDown": 0,
                    "ServicesDownReason": null,
                    "EntryPerProtocol": {
                        "OpenVPNUDP": {
                            "IPv4": "1.1.1.2",
                            "Ports": [8080, 8081]
                        }
                    }
                },
                {
                    "EntryIP": "89.39.107.201",
                    "ExitIP": "89.39.107.201",
                    "Domain": "nl-112.protonvpn.com",
                    "ID": "SlU3wQzh",
                    "Label": "",
                    "X25519PublicKey": null,
                    "Generation": 0,
                    "Status": 0,
                    "ServicesDown": 0,
                    "ServicesDownReason": null
                }
            ],
            "Load": 0
        },
        {
            "Name": "US-FREE#1",
            "EntryCountry": "US",
            "ExitCountry": "US",
            "Domain": "us-free-01.protonvpn.com",
            "Tier": 0,
            "Features": 0,
            "Region": null,
            "City": null,
            "Score": 3.1059600600000001,
            "HostCountry": null,
            "ID": "uMWqCWKSkZI=",
            "Location": {
                "Lat": 38.770099999999999,
                "Long": -77.632099999999994
            },
            "Status": 0,
            "Servers": [
                {
                    "EntryIP": "108.59.0.37",
                    "ExitIP": "108.59.0.37",
                    "Domain": "us-va-101.protonvpn.com",
                    "ID": "Uc0Z4tdf4clwVr4eDSPY0bWjH9kIzvLeQ-qudaHD-WJKY21IfFV2t73civ-hnJN7dtbGpV5eUfX5DOKE_nWWcQ==",
                    "Label": "",
                    "X25519PublicKey": null,
                    "Generation": 0,
                    "Status": 0,
                    "ServicesDown": 0,
                    "ServicesDownReason": null,
                    "EntryPerProtocol": {
                        "WireGuardUDP": {
                            "IPv4": null,
                            "Ports": null
                        }
                    }
                },
                {
                    "EntryIP": "108.59.0.38",
                    "ExitIP": "108.59.0.38",
                    "Domain": "us-va-102.protonvpn.com",
                    "ID": "CaioC57NM0BfA3WDRAG8LApascUxftg9U2rl4nU8OrqWfQfm_xO1A03EJR7XBYwGlx81IylQrK5DHhXsPt7MtQ==",
                    "Label": "",
                    "X25519PublicKey": null,
                    "Generation": 0,
                    "Status": 0,
                    "ServicesDown": 0,
                    "ServicesDownReason": null
                },
                {
                    "EntryIP": "108.59.0.39",
                    "ExitIP": "108.59.0.39",
                    "Domain": "us-va-103.protonvpn.com",
                    "ID": "qh_qQPwjLZU-Uzx2oXLq5Bl3eS-gjhYm7mxO5rCBzGMa7oLhNMfshPmpP9QWj7d52NOT3X_UVLujhrnHigo3-w==",
                    "Label": "",
                    "X25519PublicKey": null,
                    "Generation": 0,
                    "Status": 0,
                    "ServicesDown": 0,
                    "ServicesDownReason": null
                },
                {
                    "EntryIP": "192.96.203.69",
                    "ExitIP": "192.96.203.69",
                    "Domain": "us-va-105.protonvpn.com",
                    "ID": "8XiPu2ESH0R75Uy1GwwsyCozPE-s6Kj2bzI6Y6y6cvMvGNS_mg4jyn1ISvQCXL2meKCke1Uhek10wthQofxI1g==",
                    "Label": "",
                    "X25519PublicKey": null,
                    "Generation": 0,
                    "Status": 0,
                    "ServicesDown": 0,
                    "ServicesDownReason": null
                },
                {
                    "EntryIP": "192.96.203.70",
                    "ExitIP": "192.96.203.70",
                    "Domain": "us-va-106.protonvpn.com",
                    "ID": "2fzIRNasmFQoJWJlGfdZsWn2Ml_5m5L6fNT6nSiOvKkPs12exOlDe04jbp2GSZRXFnj_iva7h8jEKe3d1MVAvQ==",
                    "Label": "",
                    "X25519PublicKey": null,
                    "Generation": 0,
                    "Status": 0,
                    "ServicesDown": 0,
                    "ServicesDownReason": null
                },
                {
                    "EntryIP": "207.244.109.179",
                    "ExitIP": "207.244.109.179",
                    "Domain": "us-va-109.protonvpn.com",
                    "ID": "n8rT_cAdamsvX-hRp0NJC1QQAJ0guJWlQ3CIYw_MWCOmfewO_8cjyFG6YTTL-_Hl8nJjhdf39cSDXfXn9XcurA==",
                    "Label": "",
                    "X25519PublicKey": null,
                    "Generation": 0,
                    "Status": 0,
                    "ServicesDown": 0,
                    "ServicesDownReason": null
                },
                {
                    "EntryIP": "207.244.109.180",
                    "ExitIP": "207.244.109.180",
                    "Domain": "us-va-110.protonvpn.com",
                    "ID": "lRE3UwLV1Do-w3DiOBbC5SW4vWOAli2YGqnraOLYbylmkM8RBpJVijqKjz5CWroZ2VozjSboH7uGXlgEymGEOg==",
                    "Label": "",
                    "X25519PublicKey": null,
                    "Generation": 0,
                    "Status": 0,
                    "ServicesDown": 0,
                    "ServicesDownReason": null
                },
                {
                    "EntryIP": "209.58.142.154",
                    "ExitIP": "209.58.142.154",
                    "Domain": "us-ca-101.protonvpn.com",
                    "ID": "gze3wfvKprRzrcioqFxUqRsb-_LUQuigw0oMLznyk-Rz9SpNarGuYvC34Uuw9jwbqt_p4LfOKwhqnB2DsX3xOA==",
                    "Label": "",
                    "X25519PublicKey": null,
                    "Generation": 0,
                    "Status": 0,
                    "ServicesDown": 0,
                    "ServicesDownReason": null
                },
                {
                    "EntryIP": "209.58.142.155",
                    "ExitIP": "209.58.142.155",
                    "Domain": "us-ca-102.protonvpn.com",
                    "ID": "BcMR48g9A40xFDikwlypz_0HUcAuDg4JLXaIXnU_3GTaHhMMpDAYmwLPSpslKww7jM980F3yTbkdDle-PQ1ZmQ==",
                    "Label": "",
                    "X25519PublicKey": null,
                    "Generation": 0,
                    "Status": 0,
                    "ServicesDown": 0,
                    "ServicesDownReason": null
                },
                {
                    "EntryIP": "209.58.142.157",
                    "ExitIP": "209.58.142.157",
                    "Domain": "us-ca-104.protonvpn.com",
                    "ID": "Rc1jL2pgiCS80W-hQ9FXPDU24H3w17cSKsoMPzjzBDYeE_YeSbKUcDV7BzfUpUQibfRP0flcI8zcIkhltwDaYQ==",
                    "Label": "",
                    "X25519PublicKey": null,
                    "Generation": 0,
                    "Status": 0,
                    "ServicesDown": 0,
                    "ServicesDownReason": null
                },
                {
                    "EntryIP": "209.58.142.158",
                    "ExitIP": "209.58.142.158",
                    "Domain": "us-ca-105.protonvpn.com",
                    "ID": "M0prDxG_M62NNnt_YYUmDifQTdLIsZED9sxRIXC4NscVDojDBDo1P04w-cRFYjkNFv35hV07jP9RzcOUTxE6Cw==",
                    "Label": "",
                    "X25519PublicKey": null,
                    "Generation": 0,
                    "Status": 0,
                    "ServicesDown": 0,
                    "ServicesDownReason": null
                },
                {
                    "EntryIP": "209.58.142.159",
                    "ExitIP": "209.58.142.159",
                    "Domain": "us-ca-106.protonvpn.com",
                    "ID": "T3bFSHk4Sz7kkijmUnleDQpzWoZAPOaJY-ezFjkxdVB59YJdlUPgqeywUDpkzh5Cjaih3jYnSCLMmZ735mGTcA==",
                    "Label": "",
                    "X25519PublicKey": null,
                    "Generation": 0,
                    "Status": 0,
                    "ServicesDown": 0,
                    "ServicesDownReason": null
                },
                {
                    "EntryIP": "209.58.142.161",
                    "ExitIP": "209.58.142.161",
                    "Domain": "us-ca-108.protonvpn.com",
                    "ID": "o5MB0znIKWC8H7dQ5UEqq8eIny-YTUiN7IF0nTdr1yv8j63rBtwtxv6UeY7kRRjA3i2JTg32V7rhvumdrOn7oQ==",
                    "Label": "",
                    "X25519PublicKey": null,
                    "Generation": 0,
                    "Status": 0,
                    "ServicesDown": 0,
                    "ServicesDownReason": null
                },
                {
                    "EntryIP": "209.58.147.210",
                    "ExitIP": "209.58.147.210",
                    "Domain": "us-tx-101.protonvpn.com",
                    "ID": "2qf5zHWX_gSnFb8SHvLDBPIDhynjf3tvlv4-CBhXF6K-ZpROISfDmU8yDFdJ1gpKDMQgOpO0YneL04aOXEfLrg==",
                    "Label": "",
                    "X25519PublicKey": null,
                    "Generation": 0,
                    "Status": 0,
                    "ServicesDown": 0,
                    "ServicesDownReason": null
                },
                {
                    "EntryIP": "209.58.147.238",
                    "ExitIP": "209.58.147.238",
                    "Domain": "us-tx-102.protonvpn.com",
                    "ID": "kJ1HMEZ6D6mf08-mWOIHwqC6VtPySj4EMJ3X9-sV2DiX25JvTAX9PO0lwP2mMmiLVz5uVXACnmueOK8zrpD8Mw==",
                    "Label": "",
                    "X25519PublicKey": null,
                    "Generation": 0,
                    "Status": 0,
                    "ServicesDown": 0,
                    "ServicesDownReason": null
                },
                {
                    "EntryIP": "209.58.147.239",
                    "ExitIP": "209.58.147.239",
                    "Domain": "us-tx-103.protonvpn.com",
                    "ID": "jhRK9RMDowi2TaAIeOfK3xlOizL7ox_JrO-euMCD1h4HiNo87_wRsbPjvmUACGttSPfpnySVExjxIgKR7YMUjA==",
                    "Label": "",
                    "X25519PublicKey": null,
                    "Generation": 0,
                    "Status": 0,
                    "ServicesDown": 0,
                    "ServicesDownReason": null
                },
                {
                    "EntryIP": "209.58.147.241",
                    "ExitIP": "209.58.147.241",
                    "Domain": "us-tx-104.protonvpn.com",
                    "ID": "n6_cQciFQkEoTpy57hedhxZic_6GXA3MZgMRZAa8TMCW8m78md5y43YNhbCepjjyCibOxbXRwpW0tPaVgN4e1w==",
                    "Label": "",
                    "X25519PublicKey": null,
                    "Generation": 0,
                    "Status": 0,
                    "ServicesDown": 0,
                    "ServicesDownReason": null
                },
                {
                    "EntryIP": "204.188.215.219",
                    "ExitIP": "204.188.215.219",
                    "Domain": "us-il-101.protonvpn.com",
                    "ID": "Pi2oh46FYf7bW-UvNWGdjyDWJHKvT9JAAa2w2eQKG6qRRgJlGDbCMCPW97luYzrfdO-AS9XhG0v5mqiqRaMDWQ==",
                    "Label": "",
                    "X25519PublicKey": null,
                    "Generation": 0,
                    "Status": 0,
                    "ServicesDown": 0,
                    "ServicesDownReason": null
                },
                {
                    "EntryIP": "204.188.215.220",
                    "ExitIP": "204.188.215.220",
                    "Domain": "us-il-102.protonvpn.com",
                    "ID": "VarpLg_dy2R1z70xg91PGThGlS1vPLy7nfB_0FnqM8QU6aqgVQ-JGee8oLNa8VLaIn2PMOvrX_m19cqv6i9EtA==",
                    "Label": "",
                    "X25519PublicKey": null,
                    "Generation": 0,
                    "Status": 0,
                    "ServicesDown": 0,
                    "ServicesDownReason": null
                },
                {
                    "EntryIP": "204.188.215.221",
                    "ExitIP": "204.188.215.221",
                    "Domain": "us-il-103.protonvpn.com",
                    "ID": "fGOntxmxwfBlxhQcaV07_pQLAglcXN0rSPOr4j6jtMaFdVzJDjldRylA1SRxXZdsvmBr7d34lg_q-VPrgctZXg==",
                    "Label": "",
                    "X25519PublicKey": null,
                    "Generation": 0,
                    "Status": 0,
                    "ServicesDown": 0,
                    "ServicesDownReason": null
                },
                {
                    "EntryIP": "209.58.147.242",
                    "ExitIP": "209.58.147.242",
                    "Domain": "us-tx-105.protonvpn.com",
                    "ID": "8KjC3mH70Qk8OKXmHVcJEeZieSonJo_rlem9H-ED5xk_4xaG6VIpAXPGDUvKpdQAg49TluACcccKV_kb3QykoQ==",
                    "Label": "",
                    "X25519PublicKey": null,
                    "Generation": 0,
                    "Status": 0,
                    "ServicesDown": 0,
                    "ServicesDownReason": null
                },
                {
                    "EntryIP": "209.58.147.244",
                    "ExitIP": "209.58.147.244",
                    "Domain": "us-tx-107.protonvpn.com",
                    "ID": "icz-n4fK895K3GucbJEwP7xkJIRf6UgvflNk2qL515roPAiz9ejQmzdBDQN67f2QpUn7Z3e2BiP5l3UfMuL6Jw==",
                    "Label": "",
                    "X25519PublicKey": null,
                    "Generation": 0,
                    "Status": 0,
                    "ServicesDown": 0,
                    "ServicesDownReason": null
                },
                {
                    "EntryIP": "209.58.147.245",
                    "ExitIP": "209.58.147.245",
                    "Domain": "us-tx-108.protonvpn.com",
                    "ID": "q9e5XkG6c8OsWuNXbiP4JZDAtEOC9hJ6XmPE6UuHRf6iVjYb6BMzg1umYMmrJrkZyW7QiwF_8Jmiyctc1nQiiA==",
                    "Label": "",
                    "X25519PublicKey": null,
                    "Generation": 0,
                    "Status": 0,
                    "ServicesDown": 0,
                    "ServicesDownReason": null
                }
            ],
            "Load": 0
        }
    ]
}
"""
