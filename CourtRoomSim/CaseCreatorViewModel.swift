//
//  CaseCreatorViewModel.swift
//  CourtRoomSim
//

import SwiftUI
import CoreData
import Combine

@MainActor
final class CaseCreatorViewModel: ObservableObject {

    // MARK: published state -------------------------------------------------
    @Published private(set) var isBusy = false
    private let genManager = CaseGenerationManager()
    // MARK: UI‑binding state ----------------------------------------------
    @Published var chosenRole:  UserRole = .prosecutor     // <- NEW
    @Published var chosenModel: AiModel   = .o4Mini        // <- NEW

    // MARK: public API  (this is what RoleSelectionSheet calls) -------------
    /// Creates a brand‑new case and saves it to Core Data.
    func generate(role:  UserRole,
                  model: AiModel,
                  into  context: NSManagedObjectContext,
                  completion: @escaping (Result<CaseEntity,Error>) -> Void)
    {
        guard !isBusy else { completion(.failure(ViewModelErr.busy)); return }
        isBusy = true
        genManager.generate(into: context, role: role, model: model) { [weak self] result in
            DispatchQueue.main.async {
                self?.isBusy = false
                completion(result)
            }
        }
    }

    // ----------------------------------------------------------------------
    enum ViewModelErr: LocalizedError { case busy }
}
