//
//  AcknowledgementsViewController.swift
//  ProtonVPN - Created on 2019-11-11.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Cocoa
import PDFKit
import SwiftUI
import Theme

final class AcknowledgementsViewController: NSViewController {
    private enum Constants {
        static let defaultContentSize = NSSize(width: 634, height: 407)
    }

    private lazy var bundle: Bundle = .main
    private lazy var hostingView = NSHostingView(rootView: AcknowledgementsContentView(pdfURL: pdfURL))

    private var pdfURL: URL? {
        bundle.url(forResource: "Acknowledgements", withExtension: "pdf")
    }

    // MARK: - Init

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        hostingView.frame = NSRect(origin: .zero, size: Constants.defaultContentSize)
        hostingView.autoresizingMask = [.width, .height]
        view = hostingView
        preferredContentSize = Constants.defaultContentSize
    }
}

private struct AcknowledgementsContentView: View {
    let pdfURL: URL?

    var body: some View {
        Group {
            if let pdfURL {
                AcknowledgementsPDFView(url: pdfURL)
            } else {
                VStack(spacing: .themeSpacing8) {
                    Text("Acknowledgements are unavailable")
                        .font(.headline)
                    Text("Could not find `Acknowledgements.pdf` in the app bundle.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .padding(.themeSpacing24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct AcknowledgementsPDFView: NSViewRepresentable {
    let url: URL

    func makeNSView(context _: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displaysAsBook = false
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.document = PDFDocument(url: url)
        return view
    }

    func updateNSView(_ nsView: PDFView, context _: Context) {
        guard nsView.document == nil else { return }
        nsView.document = PDFDocument(url: url)
    }
}
