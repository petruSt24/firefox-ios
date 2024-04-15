// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import UIKit
import Common

/// Simple address toolbar implementation.
/// +-------------+------------+-----------------------+----------+------+
/// | navigation  | indicators | url       [ page    ] | browser  | menu |
/// |   actions   |            |           [ actions ] | actions  |      |
/// +-------------+------------+-----------------------+----------+------+
/// +------------------------progress------------------------------------+
public class BrowserAddressToolbar: UIView, AddressToolbar, ThemeApplicable, LocationViewDelegate {
    private enum UX {
        static let horizontalEdgeSpace: CGFloat = 16
        static let horizontalSpace: CGFloat = 8
        static let cornerRadius: CGFloat = 8
        static let dividerWidth: CGFloat = 4
        static let actionSpacing: CGFloat = 0
        static let buttonSize = CGSize(width: 40, height: 40)
    }

    private weak var toolbarDelegate: AddressToolbarDelegate?

    private lazy var navigationActionStack: UIStackView = .build()

    private lazy var locationContainer: UIView = .build { view in
        view.layer.cornerRadius = UX.cornerRadius
    }

    private lazy var locationView: LocationView = .build()
    private lazy var locationDividerView: UIView = .build()

    private lazy var pageActionStack: UIStackView = .build { view in
        view.spacing = UX.actionSpacing
    }
    private lazy var browserActionStack: UIStackView = .build()

    private var leadingBrowserActionConstraint: NSLayoutConstraint?
    private var leadingLocationContainerConstraint: NSLayoutConstraint?
    private var dividerWidthConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: .zero)
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func configure(state: AddressToolbarState,
                          toolbarDelegate: AddressToolbarDelegate) {
        updateActions(state: state)

        self.toolbarDelegate = toolbarDelegate
        locationView.configure(state.url, delegate: self)

        setNeedsLayout()
        layoutIfNeeded()
    }

    // MARK: - ThemeApplicable
    public func applyTheme(theme: Theme) {
        backgroundColor = theme.colors.layer2
        locationContainer.backgroundColor = theme.colors.layerSearch
        locationDividerView.backgroundColor = theme.colors.layer2
    }

    override public func becomeFirstResponder() -> Bool {
        return locationView.becomeFirstResponder()
    }

    override public func resignFirstResponder() -> Bool {
        return locationView.resignFirstResponder()
    }

    // MARK: - Private
    private func setupLayout() {
        addSubview(navigationActionStack)

        locationContainer.addSubview(locationView)
        locationContainer.addSubview(locationDividerView)
        locationContainer.addSubview(pageActionStack)

        addSubview(locationContainer)
        addSubview(browserActionStack)

        leadingLocationContainerConstraint = navigationActionStack.trailingAnchor.constraint(
            equalTo: locationContainer.leadingAnchor,
            constant: -UX.horizontalSpace)
        leadingLocationContainerConstraint?.isActive = true

        leadingBrowserActionConstraint = browserActionStack.leadingAnchor.constraint(
            equalTo: locationContainer.trailingAnchor,
            constant: UX.horizontalSpace)
        leadingBrowserActionConstraint?.isActive = true

        dividerWidthConstraint = locationDividerView.widthAnchor.constraint(equalToConstant: UX.dividerWidth)
        dividerWidthConstraint?.isActive = true

        let navigationActionWidthAnchor = navigationActionStack.widthAnchor.constraint(equalToConstant: 0)
        navigationActionWidthAnchor.isActive = true
        navigationActionWidthAnchor.priority = .defaultLow

        let pageActionWidthAnchor = pageActionStack.widthAnchor.constraint(equalToConstant: 0)
        pageActionWidthAnchor.isActive = true
        pageActionWidthAnchor.priority = .defaultLow

        let browserActionWidthAnchor = browserActionStack.widthAnchor.constraint(equalToConstant: 0)
        browserActionWidthAnchor.isActive = true
        browserActionWidthAnchor.priority = .defaultLow

        NSLayoutConstraint.activate([
            navigationActionStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: UX.horizontalEdgeSpace),
            navigationActionStack.topAnchor.constraint(equalTo: topAnchor),
            navigationActionStack.bottomAnchor.constraint(equalTo: bottomAnchor),

            locationContainer.topAnchor.constraint(equalTo: topAnchor),
            locationContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            locationView.leadingAnchor.constraint(equalTo: locationContainer.leadingAnchor),
            locationView.topAnchor.constraint(equalTo: locationContainer.topAnchor),
            locationView.trailingAnchor.constraint(equalTo: locationDividerView.leadingAnchor),
            locationView.bottomAnchor.constraint(equalTo: locationContainer.bottomAnchor),

            locationDividerView.topAnchor.constraint(equalTo: locationContainer.topAnchor),
            locationDividerView.trailingAnchor.constraint(equalTo: pageActionStack.leadingAnchor),
            locationDividerView.bottomAnchor.constraint(equalTo: locationContainer.bottomAnchor),

            pageActionStack.topAnchor.constraint(equalTo: locationContainer.topAnchor),
            pageActionStack.trailingAnchor.constraint(equalTo: locationContainer.trailingAnchor),
            pageActionStack.bottomAnchor.constraint(equalTo: locationContainer.bottomAnchor),

            browserActionStack.topAnchor.constraint(equalTo: topAnchor),
            browserActionStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -UX.horizontalEdgeSpace),
            browserActionStack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        updateActionSpacing()
    }

    internal func updateActions(state: AddressToolbarState) {
        // Browser actions
        updateActionStack(stackView: browserActionStack, toolbarElements: state.browserActions)

        // Navigation actions
        updateActionStack(stackView: navigationActionStack, toolbarElements: state.navigationActions)

        // Page actions
        updateActionStack(stackView: pageActionStack, toolbarElements: state.pageActions)

        updateActionSpacing()
    }

    private func updateActionStack(stackView: UIStackView, toolbarElements: [ToolbarElement]) {
        stackView.removeAllArrangedViews()
        toolbarElements.forEach { toolbarElement in
            let button = ToolbarButton()
            button.configure(element: toolbarElement)
            stackView.addArrangedSubview(button)

            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: UX.buttonSize.width),
                button.heightAnchor.constraint(equalToConstant: UX.buttonSize.height),
            ])
        }
    }

    private func updateActionSpacing() {
        // Browser action spacing
        let hasBrowserActions = !browserActionStack.arrangedSubviews.isEmpty
        leadingBrowserActionConstraint?.constant = hasBrowserActions ? UX.horizontalSpace : 0

        // Navigation action spacing
        let hasNavigationActions = !navigationActionStack.arrangedSubviews.isEmpty
        leadingLocationContainerConstraint?.constant = hasNavigationActions ? -UX.horizontalSpace : 0

        // Page action spacing
        let hasPageActions = !pageActionStack.arrangedSubviews.isEmpty
        dividerWidthConstraint?.constant = hasPageActions ? UX.dividerWidth : 0
    }

    // MARK: - LocationViewDelegate
    func locationViewDidEnterText(_ text: String) {
        toolbarDelegate?.searchSuggestions(searchTerm: text)
    }

    func locationViewDidBeginEditing(_ text: String) {
        toolbarDelegate?.openSuggestions(searchTerm: text.lowercased())
    }

    func locationViewShouldSearchFor(_ text: String) {
        guard !text.isEmpty else { return }

        toolbarDelegate?.openBrowser(searchTerm: text.lowercased())
    }
}