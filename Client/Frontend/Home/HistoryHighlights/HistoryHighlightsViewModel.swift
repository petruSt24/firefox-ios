/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Storage
import UIKit

struct HistoryHighlightsModel {
    let title: String
    let description: String?
    let favIconImage: UIImage?
    let corners: UIRectCorner?
    let hideBottomLine: Bool
    let isFillerCell: Bool
    let shouldAddShadow: Bool
    var accessibilityLabel: String {
        if let description = description {
            return "\(title), \(description)"
        } else {
            return title
        }
    }

    init(title: String,
         description: String?,
         shouldHideBottomLine: Bool,
         with corners: UIRectCorner? = nil,
         and heroImage: UIImage? = nil,
         andIsFillerCell: Bool = false,
         shouldAddShadow: Bool = false) {

        self.title = title
        self.description = description
        self.hideBottomLine = shouldHideBottomLine
        self.corners = corners
        self.favIconImage = heroImage
        self.isFillerCell = andIsFillerCell
        self.shouldAddShadow = shouldAddShadow
    }

    // Filler cell init
    init(shouldHideBottomLine: Bool,
         with corners: UIRectCorner? = nil,
         shouldAddShadow: Bool) {

        self.init(title: "",
                  description: "",
                  shouldHideBottomLine: shouldHideBottomLine,
                  with: corners,
                  and: nil,
                  andIsFillerCell: true,
                  shouldAddShadow: shouldAddShadow)
    }
}

class HistoryHighlightsViewModel {

    struct UX {
        static let maxNumberOfItemsPerColumn = 3
        static let maxNumberOfColumns = 3
        static let estimatedCellHeight: CGFloat = 65
        static let verticalPadding: CGFloat = 8
        static let horizontalPadding: CGFloat = 16
    }

    // MARK: - Properties & Variables
    var historyItems = [HighlightItem]()
    private var profile: Profile
    private var isPrivate: Bool
    private var tabManager: TabManagerProtocol
    private var urlBar: URLBarViewProtocol
    private lazy var siteImageHelper = SiteImageHelper(profile: profile)
    private var hasSentSectionEvent = false
    private var historyHighlightsDataAdaptor: HistoryHighlightsDataAdaptor
    var onTapItem: ((HighlightItem) -> Void)?
    var historyHighlightLongPressHandler: ((HighlightItem, UIView?) -> Void)?
    var headerButtonAction: ((UIButton) -> Void)?
    weak var delegate: HomepageDataModelDelegate?

    // MARK: - Variables
    /// We calculate the number of columns dynamically based on the numbers of items
    /// available such that we always have the appropriate number of columns for the
    /// rest of the dynamic calculations.
    var numberOfColumns: Int {
        return Int(ceil(Double(historyItems.count) / Double(UX.maxNumberOfItemsPerColumn)))
    }

    var numberOfRows: Int {
        return historyItems.count < UX.maxNumberOfItemsPerColumn ? historyItems.count : UX.maxNumberOfItemsPerColumn
    }

    /// Group weight used to create collection view compositional layout
    /// Case 1: For compact and a single column use 0.9 to occupy must of the width of the parent
    /// Case 2: For compact and multiple columns 0.8 to show part of the next column
    /// Case 3: For ipad we use 1/3 of the available width
    var groupWidthWeight: NSCollectionLayoutDimension {
        let groupWidth: NSCollectionLayoutDimension
        if UIScreen.main.traitCollection.horizontalSizeClass == .compact {
            let weight = numberOfColumns == 1 ? 0.9 : 0.8
            groupWidth = NSCollectionLayoutDimension.fractionalWidth(weight)
        } else {
            groupWidth = NSCollectionLayoutDimension.fractionalWidth(1/3)
        }
        return groupWidth
    }

    // MARK: - Inits
    init(with profile: Profile,
         isPrivate: Bool,
         tabManager: TabManagerProtocol,
         urlBar: URLBarViewProtocol,
         historyHighlightsDataAdaptor: HistoryHighlightsDataAdaptor) {
        self.profile = profile
        self.isPrivate = isPrivate
        self.tabManager = tabManager
        self.urlBar = urlBar
        self.historyHighlightsDataAdaptor = historyHighlightsDataAdaptor
        self.historyHighlightsDataAdaptor.delegate = self
    }

    // MARK: - Public methods

    func recordSectionHasShown() {
        if !hasSentSectionEvent {
            TelemetryWrapper.recordEvent(category: .action,
                                         method: .view,
                                         object: .historyImpressions,
                                         value: nil,
                                         extras: nil)
            hasSentSectionEvent = true
        }
    }

    func switchTo(_ highlight: HighlightItem) {
        if urlBar.inOverlayMode { urlBar.leaveOverlayMode() }

        onTapItem?(highlight)
        TelemetryWrapper.recordEvent(category: .action,
                                     method: .tap,
                                     object: .firefoxHomepage,
                                     value: .historyHighlightsItemOpened)
    }

    // TODO: Good candidate for protocol because is used in JumpBackIn and here
    func getFavIcon(for site: Site, completion: @escaping (UIImage?) -> Void) {
        siteImageHelper.fetchImageFor(site: site, imageType: .favicon, shouldFallback: false) { image in
            completion(image)
        }
    }

    func getItemDetailsAt(index: Int) -> HighlightItem? {
        guard let selectedItem = historyItems[safe: index] else { return nil }

        return selectedItem
    }

    func delete(_ item: HighlightItem) {
        historyHighlightsDataAdaptor.delete(item)
    }
}

// MARK: HomeViewModelProtocol
extension HistoryHighlightsViewModel: HomepageViewModelProtocol, FeatureFlaggable {

    var sectionType: HomepageSectionType {
        return .historyHighlights
    }

    var headerViewModel: LabelButtonHeaderViewModel {
        return LabelButtonHeaderViewModel(title: HomepageSectionType.historyHighlights.title,
                                          titleA11yIdentifier: AccessibilityIdentifiers.FirefoxHomepage.SectionTitles.historyHighlights,
                                          isButtonHidden: false,
                                          buttonTitle: .RecentlySavedShowAllText,
                                          buttonAction: headerButtonAction,
                                          buttonA11yIdentifier: AccessibilityIdentifiers.FirefoxHomepage.MoreButtons.historyHighlights)
    }

    var isEnabled: Bool {
        guard featureFlags.isFeatureEnabled(.historyHighlights, checking: .buildAndUser) else { return false }

        return !isPrivate
    }

    func section(for traitCollection: UITraitCollection) -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                               heightDimension: .estimated(UX.estimatedCellHeight))
        )

        let groupWidth = groupWidthWeight
        let subItems = Array(repeating: item, count: numberOfRows)
        let verticalGroup = NSCollectionLayoutGroup.vertical(
            layoutSize: NSCollectionLayoutSize(widthDimension: groupWidth,
                                               heightDimension: .estimated(UX.estimatedCellHeight)),
            subitems: subItems)

        let section = NSCollectionLayoutSection(group: verticalGroup)
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                heightDimension: .estimated(34))
        let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize,
                                                                 elementKind: UICollectionView.elementKindSectionHeader,
                                                                 alignment: .top)
        section.boundarySupplementaryItems = [header]

        let leadingInset = HomepageViewModel.UX.leadingInset(traitCollection: traitCollection)
        section.contentInsets = NSDirectionalEdgeInsets(
            top: 0,
            leading: leadingInset,
            bottom: HomepageViewModel.UX.spacingBetweenSections,
            trailing: 0)
        section.orthogonalScrollingBehavior = .continuous

        return section
    }

    func numberOfItemsInSection() -> Int {
        // If there are less than or equal items to the max number of items allowed per column,
        // we can return the standard count, as we don't need to display filler cells.
        // However, if there's more items, filler cells needs to be accounted for, so sections
        // are always a multiple of the max number of items allowed per column.
        if historyItems.count <= UX.maxNumberOfItemsPerColumn {
            return historyItems.count
        } else {
            return numberOfColumns * UX.maxNumberOfItemsPerColumn
        }
    }

    var hasData: Bool {
        return !historyItems.isEmpty
    }

    func updatePrivacyConcernedSection(isPrivate: Bool) {
        self.isPrivate = isPrivate
    }

    func refreshData(for traitCollection: UITraitCollection,
                     isPortrait: Bool = UIWindow.isPortrait,
                     device: UIUserInterfaceIdiom = UIDevice.current.userInterfaceIdiom) {}
}

// MARK: FxHomeSectionHandler
extension HistoryHighlightsViewModel: HomepageSectionHandler {

    func configure(_ cell: UICollectionViewCell,
                   at indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = cell as? HistoryHighlightsCell else { return UICollectionViewCell() }

        recordSectionHasShown()

        let hideBottomLine = isBottomCell(indexPath: indexPath,
                                          totalItems: historyItems.count)
        let cornersToRound = determineCornerToRound(indexPath: indexPath,
                                                    totalItems: historyItems.count)
        let shouldAddShadow = isBottomOfColumn(with: indexPath.row,
                                               totalItems: historyItems.count)

        guard let item = historyItems[safe: indexPath.row] else {
            return configureFillerCell(cell,
                                       hideBottomLine: hideBottomLine,
                                       cornersToRound: cornersToRound,
                                       shouldAddShadow: shouldAddShadow)
        }

        if item.type == .item {
            return configureIndividualHighlightCell(cell,
                                                    hideBottomLine: hideBottomLine,
                                                    cornersToRound: cornersToRound,
                                                    shouldAddShadow: shouldAddShadow,
                                                    item: item)
        } else {
            return configureGroupHighlightCell(cell,
                                               hideBottomLine: hideBottomLine,
                                               cornersToRound: cornersToRound,
                                               shouldAddShadow: shouldAddShadow,
                                               item: item)
        }
    }

    func didSelectItem(at indexPath: IndexPath,
                       homePanelDelegate: HomePanelDelegate?,
                       libraryPanelDelegate: LibraryPanelDelegate?) {

        if let highlight = historyItems[safe: indexPath.row] {
            switchTo(highlight)
        }
    }

    func handleLongPress(with collectionView: UICollectionView, indexPath: IndexPath) {
        guard let longPressHandler = historyHighlightLongPressHandler,
              let selectedItem = getItemDetailsAt(index: indexPath.row)
        else { return }

        let sourceView = collectionView.cellForItem(at: indexPath)
        longPressHandler(selectedItem, sourceView)
    }

    // MARK: - Cell helper functions

    /// Determines whether or not, given a certain number of items, a cell's given index
    /// path puts it at the bottom of its section, for any matrix.
    ///
    /// - Parameters:
    ///   - indexPath: The given cell's `IndexPath`
    ///   - totalItems: The number of total items
    /// - Returns: A boolean describing whether or the cell is a bottom cell.
    private func isBottomCell(indexPath: IndexPath, totalItems: Int?) -> Bool {
        guard let totalItems = totalItems else { return false }

        // First check if this is the last item in the list
        if indexPath.row == totalItems - 1
            || isBottomOfColumn(with: indexPath.row, totalItems: totalItems) { return true }

        return false
    }

    private func isBottomOfColumn(with currentIndex: Int, totalItems: Int) -> Bool {
        guard numberOfColumns > 0 else { return false }
        var bottomCellIndex: Int

        for column in 1...numberOfColumns {
            bottomCellIndex = (UX.maxNumberOfItemsPerColumn * column) - 1
            if currentIndex == bottomCellIndex { return true }
        }

        return false
    }

    private func determineCornerToRound(indexPath: IndexPath, totalItems: Int?) -> UIRectCorner {
        guard let totalItems = totalItems else { return [] }

        var cornersToRound = UIRectCorner()

        if isTopLeftCell(index: indexPath.row) { cornersToRound.insert(.topLeft) }
        if isTopRightCell(index: indexPath.row, totalItems: totalItems) { cornersToRound.insert(.topRight) }
        if isBottomLeftCell(index: indexPath.row, totalItems: totalItems) { cornersToRound.insert(.bottomLeft) }
        if isBottomRightCell(index: indexPath.row, totalItems: totalItems) { cornersToRound.insert(.bottomRight) }

        return cornersToRound
    }

    private func isTopLeftCell(index: Int) -> Bool {
        return index == 0
    }

    private func isTopRightCell(index: Int, totalItems: Int) -> Bool {
        let topRightIndex = (UX.maxNumberOfItemsPerColumn * (numberOfColumns - 1))
        return index == topRightIndex
    }

    private func isBottomLeftCell(index: Int, totalItems: Int) -> Bool {
        var bottomLeftIndex: Int {
            if totalItems <= UX.maxNumberOfItemsPerColumn {
                return totalItems - 1
            } else {
                return UX.maxNumberOfItemsPerColumn - 1
            }
        }

        if index == bottomLeftIndex { return true }

        return false
    }

    private func isBottomRightCell(index: Int, totalItems: Int) -> Bool {
        var bottomRightIndex: Int {
            if totalItems <= UX.maxNumberOfItemsPerColumn {
                return totalItems - 1
            } else {
                return (UX.maxNumberOfItemsPerColumn * numberOfColumns) - 1
            }
        }

        if index == bottomRightIndex { return true }

        return false
    }

    private func configureIndividualHighlightCell(_ cell: UICollectionViewCell,
                                                  hideBottomLine: Bool,
                                                  cornersToRound: UIRectCorner,
                                                  shouldAddShadow: Bool,
                                                  item: HighlightItem) -> UICollectionViewCell {

        guard let cell = cell as? HistoryHighlightsCell else { return UICollectionViewCell() }

        let itemURL = item.siteUrl?.absoluteString ?? ""
        let site = Site(url: itemURL, title: item.displayTitle)

        let cellOptions = HistoryHighlightsModel(title: item.displayTitle,
                                                 description: nil,
                                                 shouldHideBottomLine: hideBottomLine,
                                                 with: cornersToRound,
                                                 shouldAddShadow: shouldAddShadow)

        cell.updateCell(with: cellOptions)

        getFavIcon(for: site) { image in
            cell.heroImage.image = image
        }

        return cell
    }

    private func configureGroupHighlightCell(_ cell: UICollectionViewCell,
                                             hideBottomLine: Bool,
                                             cornersToRound: UIRectCorner,
                                             shouldAddShadow: Bool,
                                             item: HighlightItem) -> UICollectionViewCell {

        guard let cell = cell as? HistoryHighlightsCell else { return UICollectionViewCell() }

        let cellOptions = HistoryHighlightsModel(title: item.displayTitle,
                                                 description: item.description,
                                                 shouldHideBottomLine: hideBottomLine,
                                                 with: cornersToRound,
                                                 shouldAddShadow: shouldAddShadow)

        cell.updateCell(with: cellOptions)

        return cell

    }

    private func configureFillerCell(_ cell: UICollectionViewCell,
                                     hideBottomLine: Bool,
                                     cornersToRound: UIRectCorner,
                                     shouldAddShadow: Bool) -> UICollectionViewCell {

        guard let cell = cell as? HistoryHighlightsCell else { return UICollectionViewCell() }

        let cellOptions = HistoryHighlightsModel(shouldHideBottomLine: hideBottomLine,
                                                 with: cornersToRound,
                                                 shouldAddShadow: shouldAddShadow)

        cell.updateCell(with: cellOptions)
        return cell
    }
}

// MARK: - HistoryHighlightsDelegate

extension HistoryHighlightsViewModel: HistoryHighlightsDelegate {
    func didLoadNewData() {
        ensureMainThread {
            self.historyItems = self.historyHighlightsDataAdaptor.getHistoryHightlights()
            guard self.isEnabled else { return }
            self.delegate?.reloadView()
        }
    }
}
