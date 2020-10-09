//
//  ViewController.swift
//  CombineFormViewModel
//
//  Created by Spencer Prescott on 10/5/20.
//

import UIKit
import Combine

protocol FormService {
    func fetchForms() -> AnyPublisher<[FormField], Never>
}

class MockFormService: FormService {
    func fetchForms() -> AnyPublisher<[FormField], Never> {
        return Just([FormField(id: UUID(), placeholder: "Hi"), FormField(id: UUID(), placeholder: "Everybody")])
            .eraseToAnyPublisher()
    }
}

class FormViewModel: ObservableObject {
    @Published var formFields: [FormField] = []
    @Published var isFormValid: Bool = false

    private let formService: FormService
    private var fetchFormsCancellable: AnyCancellable?
    private var formFieldsText: [FormField: String?] = [:]

    init(formService: FormService) {
        self.formService = formService
    }

    func didLoad() {
        // Form Service could just be enqueuing operations, it does not matter to the view model
        // Form Service could also just utilize closures instead of Combine if we do not want to introduce
        // Combine to the operation layer yet

        fetchFormsCancellable = formService
            .fetchForms()
            .sink(receiveValue: { [weak self] formFields in
                self?.formFieldsText = formFields.reduce(into: [:], { result, formField in
                    result[formField] = ""
                })
                self?.formFields = formFields
            })
    }

    func updateFormFieldText(text: String?, formField: FormField) {
        formFieldsText[formField] = text

        // Some validation logic
        isFormValid = formFieldsText.filter { key, value in value?.isEmpty == true }.count == 0
    }
}

struct FormField: Equatable, Hashable {
    let id: UUID
    let placeholder: String
}

class FormView: UIView {
    private let stackView: UIStackView = {
        let v = UIStackView()
        v.axis = .vertical
        v.spacing = 8
        return v
    }()

    private var cancellables = Set<AnyCancellable>()

    let formFieldTextDidChange = PassthroughSubject<(String?, FormField), Never>()

    init() {
        super.init(frame: .zero)

        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateFormFields(_ formFields: [FormField]) {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        cancellables = []

        let textFields = formFields.map { formField -> UITextField in
            let textField = UITextField()
            textField.attributedPlaceholder = NSAttributedString(string: formField.placeholder, attributes: [
                .foregroundColor: UIColor.systemGray6
            ])

            // Observe text change
            textField.textPublisher
                .map { ($0, formField) }
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: formFieldTextDidChange.send)
                .store(in: &cancellables)

            return textField
        }

        textFields.forEach { textField in
            stackView.addArrangedSubview(textField)
            NSLayoutConstraint.activate([
                textField.heightAnchor.constraint(equalToConstant: 50)
            ])
        }
    }
}

class ViewController : UIViewController {
    private let _view = FormView()
    private let viewModel: FormViewModel
    private var cancellables = Set<AnyCancellable>()
    
    init(viewModel: FormViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(_view)
        _view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            _view.topAnchor.constraint(equalTo: view.topAnchor),
            _view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            _view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            _view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        viewModel.$formFields
            .receive(on: DispatchQueue.main)
            .sink { [weak self] formFields in
                self?._view.updateFormFields(formFields)
            }
            .store(in: &cancellables)

        viewModel.$isFormValid
            .receive(on: DispatchQueue.main)
            .map { $0 ? UIColor.systemGreen : UIColor.systemRed }
            .assign(to: \.backgroundColor, on: _view)
            .store(in: &cancellables)

        _view.formFieldTextDidChange
            .sink(receiveValue: viewModel.updateFormFieldText)
            .store(in: &cancellables)

        viewModel.didLoad()
    }
}

extension UITextField {
    var textPublisher: AnyPublisher<String?, Never> {
        NotificationCenter.default
            .publisher(for: UITextField.textDidChangeNotification, object: self)
            .compactMap { $0.object as? UITextField }
            .map { $0.text }
            .eraseToAnyPublisher()
    }
}




class FormViewModelClosures {
    private var formFields: [FormField] = [] {
        didSet {
            didUpdateFormFields?(formFields)
        }
    }
    private var isFormValid: Bool = false {
        didSet {
            didUpdateIsFormValid?(isFormValid)
        }
    }
    private let formService: FormService
    private var fetchFormsCancellable: AnyCancellable?
    private var formFieldsText: [FormField: String?] = [:]

    var didUpdateFormFields: (([FormField]) -> Void)?
    var didUpdateIsFormValid: ((Bool) -> Void)?

    init(formService: FormService) {
        self.formService = formService
    }

    func didLoad() {
        // Just enqueue operations here
        fetchFormsCancellable = formService
            .fetchForms()
            .sink(receiveValue: { [weak self] formFields in
                self?.formFieldsText = formFields.reduce(into: [:], { result, formField in
                    result[formField] = ""
                })
                self?.formFields = formFields
            })
    }

    func updateFormFieldText(text: String?, formField: FormField) {
        formFieldsText[formField] = text

        // Some validation logic
        isFormValid = formFieldsText.filter { key, value in value?.isEmpty == true }.count == 0
    }

}
