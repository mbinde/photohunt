import Foundation
import CoreData

extension HuntListEntity {
    var itemsArray: [HuntItemEntity] {
        let set = items as? Set<HuntItemEntity> ?? []
        return set.sorted { $0.sortOrder < $1.sortOrder }
    }
}
