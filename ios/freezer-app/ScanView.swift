//
//  ScanView.swift
//  freezer-app
//
//  Created by Andreas Gößl on 24.04.26.
//

import SwiftUI
import Vision
import AVFoundation

struct ScanView: View {
    private struct PresentedUnit: Identifiable {
        let id: UUID
        let displayName: String?
    }

    private struct CreateCode128Draft: Identifiable {
        let id = UUID()
        let codeValue: String
        let reusableUnitID: UUID?
    }

    private struct UndoItem: Identifiable {
        let id: UUID
        let title: String
    }

    private struct RecognizedCodeAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    @State private var recognizedAlert: RecognizedCodeAlert?
    @State private var scannerMessage: String?
    @State private var presentedUnit: PresentedUnit?
    @State private var createDraft: CreateCode128Draft?
    @State private var undoItem: UndoItem?
    @State private var isTorchOn = false
    @State private var zoomFactor: CGFloat = 1
    @State private var baseZoomFactor: CGFloat = 1
    @State private var isResolvingScan = false
    @State private var isViewVisible = false
    private let inventoryRepository = InventoryRepository()

    var body: some View {
        NavigationStack {
            Group {
                if AVCaptureDevice.default(for: .video) != nil {
                    scannerContent
                } else {
                    scannerUnavailableView(
                        title: "Scanner nicht unterstützt",
                        message: "Dieses Gerät unterstützt den nativen Code-Scanner nicht."
                    )
                }
            }
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.inline)
            .alert(
                recognizedAlert?.title ?? "Code erkannt",
                isPresented: recognizedAlertBinding,
                presenting: recognizedAlert
            ) { _ in
                Button("OK") {
                    recognizedAlert = nil
                }
            } message: { alert in
                Text(alert.message)
            }
            .alert(
                "Scanner nicht verfügbar",
                isPresented: scannerMessageAlertBinding,
                presenting: scannerMessage
            ) { _ in
                Button("OK") {
                    scannerMessage = nil
                }
            } message: { message in
                Text(message)
            }
            .sheet(item: $presentedUnit) { unit in
                UnitDetailView(
                    unitId: unit.id,
                    displayName: unit.displayName,
                    onConsumeClose: { presentedUnit = nil }
                )
            }
            .sheet(item: $createDraft) { draft in
                createDraftSheet(for: draft)
            }
            .overlay(alignment: .bottom) { undoBannerOverlay }
        }
        .onAppear {
            isViewVisible = true
        }
        .onDisappear {
            isViewVisible = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .unitDetailDidConsume)) { notification in
            guard
                let id = notification.userInfo?[AppNotificationKey.unitID] as? UUID,
                let title = notification.userInfo?[AppNotificationKey.title] as? String
            else { return }
            withAnimation(.snappy(duration: 0.28, extraBounce: 0)) {
                undoItem = UndoItem(id: id, title: title)
            }
        }
        .onChange(of: undoItem?.id) { _, newValue in
            guard let newValue else { return }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard undoItem?.id == newValue else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    undoItem = nil
                }
            }
        }
    }

    private var scannerContent: some View {
        ZStack(alignment: .bottomTrailing) {
            BarcodeScannerView(
                isPaused: isScannerPaused || !isViewVisible,
                isTorchOn: isTorchOn,
                zoomFactor: zoomFactor,
                onRecognized: { payload in
                    handleRecognizedCode(payload)
                },
                onFailure: { message in
                    scannerMessage = message
                }
            )
            .ignoresSafeArea(edges: .bottom)

            if isTorchAvailable {
                Button {
                    AppHaptics.selection()
                    isTorchOn.toggle()
                } label: {
                    Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isTorchOn ? .black : .white)
                        .frame(width: 44, height: 44)
                        .background(
                            isTorchOn
                                ? Color.white.opacity(0.96)
                                : Color.black.opacity(0.38),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .padding(.trailing, 18)
                .padding(.bottom, 120)
            }

            scannerHint
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .background(Color.black.ignoresSafeArea())
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    zoomFactor = min(max(baseZoomFactor * value.magnification, 1), 5)
                }
                .onEnded { value in
                    baseZoomFactor = min(max(baseZoomFactor * value.magnification, 1), 5)
                    zoomFactor = baseZoomFactor
                }
        )
    }

    private var scannerHint: some View {
        VStack(spacing: 10) {
            Text("Barcode scannen")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Code 128 öffnet direkt den Eintrag oder die Anlagemaske.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(.black.opacity(0.42))
    }

    private func createDraftSheet(for draft: CreateCode128Draft) -> some View {
        ScanCreateCode128View(
            codeValue: draft.codeValue,
            reusableUnitID: draft.reusableUnitID
        ) { createdUnitID, displayName in
            createDraft = nil
            presentedUnit = PresentedUnit(id: createdUnitID, displayName: displayName)
        }
        .presentationDetents([.large])
        .presentationContentInteraction(.scrolls)
    }

    @ViewBuilder
    private var undoBannerOverlay: some View {
        if let undo = undoItem {
            UndoBanner(
                title: "\(undo.title) entnommen",
                duration: 5,
                onUndo: {
                    AppHaptics.selection()
                    Task {
                        do {
                            try await inventoryRepository.restoreUnit(id: undo.id)
                            undoItem = nil
                        } catch {
                            scannerMessage = AppError.message(for: error)
                        }
                    }
                },
                onDismiss: { undoItem = nil }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.2), value: undo.id)
        }
    }

    private func scannerUnavailableView(title: String, message: String) -> some View {
        ContentUnavailableView(
            title,
            systemImage: "barcode.viewfinder",
            description: Text(message)
        )
    }

    private var isScannerPaused: Bool {
        isResolvingScan || recognizedAlert != nil || scannerMessage != nil || presentedUnit != nil || createDraft != nil
    }

    private var isTorchAvailable: Bool {
        AVCaptureDevice.default(for: .video)?.hasTorch == true
    }

    private func handleRecognizedCode(_ payload: ScannedBarcodePayload) {
        guard !isResolvingScan else { return }

        AppHaptics.swipeAction()
        isResolvingScan = true

        Task {
            defer {
                Task { @MainActor in
                    isResolvingScan = false
                }
            }

            switch payload.kind {
            case .code128:
                await resolveCode128(payload.value)
            case .ean:
                await MainActor.run {
                    recognizedAlert = RecognizedCodeAlert(
                        title: "EAN erkannt",
                        message: payload.value
                    )
                }
            }
        }
    }

    @MainActor
    private func resolveCode128(_ code: String) async {
        do {
            if let unit = try await inventoryRepository.fetchActiveCode128Unit(codeValue: code) {
                presentedUnit = PresentedUnit(id: unit.id, displayName: unit.display_name)
            } else {
                let reusableUnitID = try await inventoryRepository.fetchReusableCode128UnitID(codeValue: code)
                createDraft = CreateCode128Draft(codeValue: code, reusableUnitID: reusableUnitID)
            }
        } catch {
            scannerMessage = AppError.message(for: error)
        }
    }

    private var recognizedAlertBinding: Binding<Bool> {
        Binding(
            get: { recognizedAlert != nil },
            set: { isPresented in
                if !isPresented {
                    recognizedAlert = nil
                }
            }
        )
    }

    private var scannerMessageAlertBinding: Binding<Bool> {
        Binding(
            get: { scannerMessage != nil },
            set: { isPresented in
                if !isPresented {
                    scannerMessage = nil
                }
            }
        )
    }
}

private struct BarcodeScannerView: UIViewControllerRepresentable {
    let isPaused: Bool
    let isTorchOn: Bool
    let zoomFactor: CGFloat
    let onRecognized: (ScannedBarcodePayload) -> Void
    let onFailure: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onRecognized: onRecognized, onFailure: onFailure)
    }

    func makeUIViewController(context: Context) -> BarcodeScannerViewController {
        let controller = BarcodeScannerViewController()
        context.coordinator.attach(to: controller)
        controller.onRecognized = onRecognized
        controller.onFailure = onFailure
        return controller
    }

    func updateUIViewController(_ uiViewController: BarcodeScannerViewController, context: Context) {
        uiViewController.setPaused(isPaused)
        uiViewController.setTorchEnabled(isTorchOn)
        uiViewController.setZoomFactor(zoomFactor)
    }

    static func dismantleUIViewController(_ uiViewController: BarcodeScannerViewController, coordinator: Coordinator) {
        uiViewController.shutdown()
    }

    @MainActor
    final class Coordinator: NSObject {
        let onRecognized: (ScannedBarcodePayload) -> Void
        let onFailure: (String) -> Void

        init(onRecognized: @escaping (ScannedBarcodePayload) -> Void, onFailure: @escaping (String) -> Void) {
            self.onRecognized = onRecognized
            self.onFailure = onFailure
        }

        func attach(to scanner: BarcodeScannerViewController) {
            scanner.onRecognized = onRecognized
            scanner.onFailure = onFailure
        }
    }
}

private final class BarcodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onRecognized: ((ScannedBarcodePayload) -> Void)?
    var onFailure: ((String) -> Void)?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "freezer-app.barcode-scanner")
    private let metadataOutput = AVCaptureMetadataOutput()
    private let previewView = CameraPreviewView()

    private var isConfigured = false
    private var isPaused = false
    private var isTorchEnabled = false
    private var zoomFactor: CGFloat = 1
    private var lastRecognizedSignature: String?

    override func loadView() {
        view = previewView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        previewView.previewLayer.session = session
        previewView.previewLayer.videoGravity = .resizeAspectFill
        configureSessionIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewView.previewLayer.frame = previewView.bounds
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        updateSessionRunningState()
    }

    func setTorchEnabled(_ enabled: Bool) {
        guard isTorchEnabled != enabled else { return }
        isTorchEnabled = enabled
        sessionQueue.async { [weak self] in
            self?.applyTorchState()
        }
    }

    func setZoomFactor(_ factor: CGFloat) {
        zoomFactor = factor
        sessionQueue.async { [weak self] in
            self?.applyZoomFactor()
        }
    }

    func shutdown() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.setTorchMode(false)
        }
    }

    private func configureSessionIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true

        sessionQueue.async { [weak self] in
            guard let self else { return }

            guard let device = AVCaptureDevice.default(for: .video) else {
                DispatchQueue.main.async {
                    self.onFailure?("Die Kamera ist auf diesem Gerät nicht verfügbar.")
                }
                return
            }

            let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
            if authStatus == .notDetermined {
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    if granted {
                        self.configureSession(device: device)
                    } else {
                        DispatchQueue.main.async {
                            self.onFailure?("Der Kamerazugriff wurde nicht erlaubt.")
                        }
                    }
                }
                return
            }

            guard authStatus == .authorized else {
                DispatchQueue.main.async {
                    self.onFailure?("Die Kamera ist eingeschränkt und kann gerade nicht verwendet werden.")
                }
                return
            }

            self.configureSession(device: device)
        }
    }

    private func configureSession(device: AVCaptureDevice) {
        do {
            let input = try AVCaptureDeviceInput(device: device)

            session.beginConfiguration()
            defer { session.commitConfiguration() }

            if session.canAddInput(input) {
                session.addInput(input)
            }

            if session.canAddOutput(metadataOutput) {
                session.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = supportedMetadataTypes()
            }

            if device.isAutoFocusRangeRestrictionSupported {
                try? device.lockForConfiguration()
                device.autoFocusRangeRestriction = .near
                device.unlockForConfiguration()
            }

            updateSessionRunningState()
        } catch {
            DispatchQueue.main.async {
                self.onFailure?(AppError.message(for: error))
            }
        }
    }

    private func supportedMetadataTypes() -> [AVMetadataObject.ObjectType] {
        let requested: [AVMetadataObject.ObjectType] = [
            .ean13, .ean8, .upce, .code39, .code128, .qr, .aztec, .pdf417
        ]
        return requested.filter { metadataOutput.availableMetadataObjectTypes.contains($0) }
    }

    private func updateSessionRunningState() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.isConfigured else { return }

            if self.isPaused {
                self.lastRecognizedSignature = nil
                if self.session.isRunning {
                    self.session.stopRunning()
                }
                self.setTorchMode(false)
            } else {
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                self.applyTorchState()
                self.applyZoomFactor()
            }
        }
    }

    private func applyTorchState() {
        setTorchMode(isTorchEnabled && !isPaused)
    }

    private func applyZoomFactor() {
        guard let device = AVCaptureDevice.default(for: .video) else { return }

        let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 5)
        let clampedFactor = min(max(zoomFactor, 1), maxZoom)

        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clampedFactor
            device.unlockForConfiguration()
        } catch {
            DispatchQueue.main.async {
                self.onFailure?("Der Zoom konnte nicht angepasst werden.")
            }
        }
    }

    private func setTorchMode(_ enabled: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }

        do {
            try device.lockForConfiguration()
            if enabled {
                try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
        } catch {
            DispatchQueue.main.async {
                self.onFailure?("Die Taschenlampe konnte nicht umgeschaltet werden.")
            }
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !isPaused else { return }

        for object in metadataObjects {
            guard
                let codeObject = object as? AVMetadataMachineReadableCodeObject,
                let value = codeObject.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                !value.isEmpty
            else { continue }

            let payload: ScannedBarcodePayload?
            switch codeObject.type {
            case .code128:
                payload = ScannedBarcodePayload(value: value, kind: .code128)
            case .ean13, .ean8, .upce:
                payload = ScannedBarcodePayload(value: value, kind: .ean)
            default:
                payload = nil
            }

            guard let payload else { continue }
            guard payload.signature != lastRecognizedSignature else { return }

            lastRecognizedSignature = payload.signature
            onRecognized?(payload)
            return
        }
    }
}

private final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

private struct ScannedBarcodePayload {
    enum Kind {
        case code128
        case ean
    }

    let value: String
    let kind: Kind

    var signature: String {
        switch kind {
        case .code128:
            "code128:\(value)"
        case .ean:
            "ean:\(value)"
        }
    }
}

private struct ScanCreateCode128View: View {
    private enum QuantityUnit: String, CaseIterable, Identifiable {
        case grams = "g"
        case portions = "portionen"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .grams: "g"
            case .portions: "Portionen"
            }
        }
    }

    let codeValue: String
    let reusableUnitID: UUID?
    let onCreated: (UUID, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var categories: [CategoryRow] = []
    @State private var locations: [LocationRow] = []
    @State private var nameOverride = ""
    @State private var frozenAtDate = Date()
    @State private var quantityText = ""
    @State private var quantityUnit: QuantityUnit = .grams
    @State private var selectedCategoryID: UUID?
    @State private var selectedLocationID: UUID?
    @State private var note = ""
    @State private var alertTitle = "Speichern fehlgeschlagen"
    @State private var alertMessage: String?
    @State private var isLoadingReferenceData = false
    @State private var isSaving = false

    private let repo = InventoryRepository()

    var body: some View {
        NavigationStack {
            Form {
                Section("Code") {
                    HStack(spacing: 12) {
                        Text(codeValue)
                            .font(.body.monospaced())
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)

                        Spacer(minLength: 12)

                        ScanCodeTypeBadge(title: "CODE128")
                    }
                }

                Section("Bezeichnung") {
                    TextField("Name", text: $nameOverride)
                }

                Section("Zuordnung") {
                    NavigationLink {
                        ScanCategorySelectionView(
                            categories: categories,
                            selectedCategoryID: $selectedCategoryID
                        )
                    } label: {
                        selectionRow(title: "Kategorie", value: selectedCategoryName)
                    }

                    Menu {
                        ForEach(locations) { location in
                            Button {
                                selectedLocationID = location.id
                            } label: {
                                if selectedLocationID == location.id {
                                    Label(location.name, systemImage: "checkmark")
                                } else {
                                    Text(location.name)
                                }
                            }
                        }
                    } label: {
                        selectionRow(title: "Ort", value: selectedLocationName, showsMenuIndicator: true)
                    }
                    .foregroundStyle(.primary)
                }

                Section("Eingelegt am") {
                    DatePicker("Datum", selection: $frozenAtDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                }

                Section("Menge") {
                    TextField(quantityUnit == .grams ? "z.B. 850" : "z.B. 3", text: $quantityText)
                        .keyboardType(.numberPad)

                    Picker("Einheit", selection: $quantityUnit) {
                        ForEach(QuantityUnit.allCases) { unit in
                            Text(unit.title).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Notiz") {
                    TextField("Optional", text: $note, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Neu anlegen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        save()
                    }
                    .disabled(isLoadingReferenceData || isSaving)
                }
            }
            .task {
                await loadReferenceData()
            }
            .alert(alertTitle, isPresented: alertBinding) {
                Button("OK", role: .cancel) {
                    alertMessage = nil
                }
            } message: {
                Text(alertMessage ?? "Bitte versuche es erneut.")
            }
        }
    }

    private func save() {
        guard validateRequiredFields() else { return }
        guard let selectedLocationID else { return }

        Task {
            isSaving = true
            defer { isSaving = false }

            let quantity = Int(quantityText.trimmingCharacters(in: .whitespacesAndNewlines))
            let name = nameOverride.trimmingCharacters(in: .whitespacesAndNewlines)
            let noteTrim = note.trimmingCharacters(in: .whitespacesAndNewlines)

            do {
                let newID = try await repo.createCode128Unit(
                    codeValue: codeValue,
                    reusingUnitID: reusableUnitID,
                    nameOverride: name.isEmpty ? nil : name,
                    frozenAt: isoDateString(from: frozenAtDate),
                    quantityValue: quantity,
                    quantityUnit: quantity == nil ? nil : quantityUnit.rawValue,
                    categoryId: selectedCategoryID,
                    locationId: selectedLocationID,
                    note: noteTrim.isEmpty ? nil : noteTrim
                )
                onCreated(newID, name.isEmpty ? nil : name)
            } catch {
                alertTitle = "Speichern fehlgeschlagen"
                alertMessage = AppError.message(for: error)
            }
        }
    }

    private func loadReferenceData() async {
        guard categories.isEmpty, locations.isEmpty else { return }
        isLoadingReferenceData = true
        defer { isLoadingReferenceData = false }

        do {
            async let categoryRequest = CategoriesRepository().fetchCategories()
            async let locationRequest = LocationsRepository().fetchLocations()
            categories = try await categoryRequest
            locations = try await locationRequest
        } catch {
            alertTitle = "Speichern fehlgeschlagen"
            alertMessage = AppError.message(for: error)
        }
    }

    private func validateRequiredFields() -> Bool {
        let name = nameOverride.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty else {
            alertTitle = "Unvollständig"
            alertMessage = "Bitte einen Titel eingeben."
            return false
        }

        guard selectedCategoryID != nil else {
            alertTitle = "Unvollständig"
            alertMessage = "Bitte eine Kategorie auswählen."
            return false
        }

        guard selectedLocationID != nil else {
            alertTitle = "Unvollständig"
            alertMessage = "Bitte einen Ort auswählen."
            return false
        }

        return true
    }

    private var selectedCategoryName: String {
        guard let selectedCategoryID,
              let category = categories.first(where: { $0.id == selectedCategoryID }) else {
            return "Keine Kategorie"
        }

        if let emoji = category.emoji, !emoji.isEmpty {
            return "\(emoji) \(category.name)"
        }
        return category.name
    }

    private var selectedLocationName: String {
        guard let selectedLocationID,
              let location = locations.first(where: { $0.id == selectedLocationID }) else {
            return "Ort wählen"
        }
        return location.name
    }

    private func selectionRow(title: String, value: String, showsMenuIndicator: Bool = false) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .foregroundStyle(.tertiary)
            if showsMenuIndicator {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func isoDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { alertMessage != nil },
            set: { newValue in
                if !newValue {
                    alertMessage = nil
                }
            }
        )
    }
}

private struct ScanCategorySelectionView: View {
    let categories: [CategoryRow]
    @Binding var selectedCategoryID: UUID?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(categories) { category in
                Button {
                    selectedCategoryID = category.id
                    dismiss()
                } label: {
                    HStack {
                        Text(categoryLabel(category))
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedCategoryID == category.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Kategorie")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func categoryLabel(_ category: CategoryRow) -> String {
        if let emoji = category.emoji, !emoji.isEmpty {
            return "\(emoji) \(category.name)"
        }
        return category.name
    }
}

private struct ScanCodeTypeBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
            )
    }
}
