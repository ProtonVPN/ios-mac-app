//
//  Created on 05/03/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import ComposableArchitecture
import PaymentsShared
import SwiftUI
import WebKit

struct PaymentsWebCheckoutView: View {
    let store: StoreOf<PaymentsWebCheckoutFeature>

    var body: some View {
        PaymentsWebContainerView(
            url: store.url,
            onCompleted: { store.send(.completedFromWeb) },
            onClosed: { store.send(.closeTapped) }
        )
    }
}

private struct PaymentsWebContainerView: View {
    let url: URL
    let onCompleted: () -> Void
    let onClosed: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if #available(iOS 26, *) {
                NativePaymentsWebView(url: url, onCompleted: onCompleted)
            } else {
                LegacyPaymentsWebView(url: url, onCompleted: onCompleted)
            }

            Button {
                onClosed()
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.black)
                    .padding(10)
                    .background(.white.opacity(0.9), in: Circle())
            }
            .padding(.top, 8)
            .padding(.trailing, 8)
        }
        .ignoresSafeArea()
    }
}

@available(iOS 26, *)
private struct NativePaymentsWebView: View {
    @State private var page = WebPage()

    let url: URL
    let onCompleted: () -> Void

    var body: some View {
        WebView(page)
            .onAppear {
                page.load(URLRequest(url: url))
            }
            .onChange(of: page.url) { _, newValue in
                guard newValue?.absoluteString.starts(with: "protonvpn://refresh") == true else { return }
                onCompleted()
            }
    }
}

private struct LegacyPaymentsWebView: UIViewRepresentable {
    let url: URL
    let onCompleted: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCompleted: onCompleted)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_: WKWebView, context _: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onCompleted: () -> Void

        init(onCompleted: @escaping () -> Void) {
            self.onCompleted = onCompleted
        }

        func webView(
            _: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.request.url?.absoluteString.starts(with: "protonvpn://refresh") == true {
                onCompleted()
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}

#if DEBUG
    #Preview("Web Checkout") {
        PaymentsWebCheckoutView(
            store: Store(
                initialState: .init(url: URL(string: "https://example.com")!)
            ) {
                PaymentsWebCheckoutFeature()
            }
        )
    }
#endif
