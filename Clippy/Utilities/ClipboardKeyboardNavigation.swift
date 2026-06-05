import Foundation

enum ClipboardKeyboardNavigation {
    static func actionItemId(
        hoveredId: UUID?,
        selectedId: UUID?,
        itemIds: [UUID],
        isQuickLookPresented: Bool,
        isQueueTabSelected: Bool
    ) -> UUID? {
        guard !isQuickLookPresented, !isQueueTabSelected else {
            return nil
        }

        let activeId = hoveredId ?? selectedId
        guard let activeId else {
            return itemIds.first
        }

        return itemIds.contains(activeId) ? activeId : itemIds.first
    }

    static func validSelectionId(
        selectedId: UUID?,
        itemIds: [UUID],
        isQueueTabSelected: Bool
    ) -> UUID? {
        guard !isQueueTabSelected, !itemIds.isEmpty else {
            return nil
        }

        if let selectedId, itemIds.contains(selectedId) {
            return selectedId
        }

        return itemIds.first
    }

    static func nextSelectionId(
        selectedId: UUID?,
        hoveredId: UUID?,
        itemIds: [UUID],
        offset: Int,
        isQuickLookPresented: Bool,
        isQueueTabSelected: Bool
    ) -> UUID? {
        guard !isQuickLookPresented, !isQueueTabSelected, !itemIds.isEmpty else {
            return nil
        }

        let currentId = selectedId ?? hoveredId
        let currentIndex = currentId.flatMap { itemIds.firstIndex(of: $0) } ?? (offset > 0 ? -1 : itemIds.count)
        let nextIndex = (currentIndex + offset + itemIds.count) % itemIds.count

        return itemIds[nextIndex]
    }
}
