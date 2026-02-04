import Foundation
import PassKit
import WebKit
import os.log

/// Manages Apple Pay integration for web checkout
@MainActor
class ApplePayManager: NSObject, ObservableObject {
    static let shared = ApplePayManager()

    // MARK: - Published Properties

    @Published var isApplePayAvailable = false
    @Published var canMakePayments = false
    @Published var isProcessingPayment = false

    // MARK: - Configuration

    private let merchantIdentifier = "merchant.com.canvas.browser"
    private let supportedNetworks: [PKPaymentNetwork] = [
        .visa, .masterCard, .amex, .discover, .JCB
    ]
    private let merchantCapabilities: PKMerchantCapability = [.threeDSecure, .debit, .credit]

    private let logger = Logger(subsystem: "com.canvas.browser", category: "ApplePay")

    // MARK: - Initialization

    override private init() {
        super.init()
        checkApplePayAvailability()
    }

    // MARK: - Availability

    func checkApplePayAvailability() {
        isApplePayAvailable = PKPaymentAuthorizationController.canMakePayments()
        canMakePayments = PKPaymentAuthorizationController.canMakePayments(usingNetworks: supportedNetworks)

        logger.info("Apple Pay available: \(self.isApplePayAvailable), can make payments: \(self.canMakePayments)")
    }

    // MARK: - Payment Request Creation

    /// Create a payment request from web page Apple Pay request
    func createPaymentRequest(from jsRequest: ApplePayJSRequest) -> PKPaymentRequest {
        let request = PKPaymentRequest()

        request.merchantIdentifier = merchantIdentifier
        request.countryCode = jsRequest.countryCode ?? "US"
        request.currencyCode = jsRequest.currencyCode ?? "USD"
        request.supportedNetworks = supportedNetworks
        request.merchantCapabilities = merchantCapabilities

        // Convert line items
        request.paymentSummaryItems = jsRequest.lineItems.map { item in
            PKPaymentSummaryItem(
                label: item.label,
                amount: NSDecimalNumber(string: item.amount),
                type: item.pending ? .pending : .final
            )
        }

        // Add total
        let total = PKPaymentSummaryItem(
            label: jsRequest.total.label,
            amount: NSDecimalNumber(string: jsRequest.total.amount),
            type: jsRequest.total.pending ? .pending : .final
        )
        request.paymentSummaryItems.append(total)

        // Shipping options
        if let shippingMethods = jsRequest.shippingMethods {
            request.shippingMethods = shippingMethods.map { method in
                PKShippingMethod(
                    label: method.label,
                    amount: NSDecimalNumber(string: method.amount)
                )
            }
        }

        // Required fields
        if jsRequest.requiredBillingContactFields?.contains("postalAddress") == true {
            request.requiredBillingContactFields = [.postalAddress]
        }

        if jsRequest.requiredShippingContactFields?.contains("postalAddress") == true {
            request.requiredShippingContactFields = [.postalAddress, .name, .phoneNumber, .emailAddress]
        }

        return request
    }

    // MARK: - Payment Authorization

    /// Present Apple Pay sheet for payment
    func authorizePayment(
        request: PKPaymentRequest,
        completion: @escaping (Result<PKPayment, ApplePayError>) -> Void
    ) {
        guard isApplePayAvailable else {
            completion(.failure(.notAvailable))
            return
        }

        guard canMakePayments else {
            completion(.failure(.noCardsConfigured))
            return
        }

        isProcessingPayment = true

        let controller = PKPaymentAuthorizationController(paymentRequest: request)
        controller.delegate = PaymentAuthorizationDelegate(completion: { [weak self] result in
            Task { @MainActor in
                self?.isProcessingPayment = false
                completion(result)
            }
        })

        controller.present { presented in
            if !presented {
                Task { @MainActor in
                    self.isProcessingPayment = false
                    completion(.failure(.presentationFailed))
                }
            }
        }

        logger.info("Presented Apple Pay authorization sheet")
    }

    // MARK: - Web Integration

    /// Handle Apple Pay JS API calls from web content
    func handleWebPaymentRequest(
        from webView: WKWebView,
        request: ApplePayJSRequest,
        completion: @escaping (ApplePayJSResponse) -> Void
    ) {
        let paymentRequest = createPaymentRequest(from: request)

        authorizePayment(request: paymentRequest) { result in
            switch result {
            case .success(let payment):
                // Create response with payment token
                let response = ApplePayJSResponse(
                    status: .success,
                    token: self.encodePaymentToken(payment.token)
                )
                completion(response)

            case .failure(let error):
                let response = ApplePayJSResponse(
                    status: .failure,
                    error: error.localizedDescription
                )
                completion(response)
            }
        }
    }

    private func encodePaymentToken(_ token: PKPaymentToken) -> String {
        // Encode payment token data as base64 for transmission to merchant server
        let tokenData = token.paymentData
        return tokenData.base64EncodedString()
    }

    // MARK: - Check Page Support

    /// Check if a URL supports Apple Pay
    func checkApplePaySupport(for url: URL, in webView: WKWebView, completion: @escaping (Bool) -> Void) {
        let script = """
            (function() {
                if (window.ApplePaySession) {
                    return ApplePaySession.canMakePayments();
                }
                return false;
            })();
        """

        webView.evaluateJavaScript(script) { result, error in
            if let supported = result as? Bool {
                completion(supported)
            } else {
                completion(false)
            }
        }
    }

    // MARK: - Inject Apple Pay Support

    /// Inject Apple Pay availability check into web page
    func injectApplePaySupport(into webView: WKWebView) {
        let script = """
            // Canvas Browser Apple Pay bridge
            if (!window.CanvasApplePay) {
                window.CanvasApplePay = {
                    available: \(isApplePayAvailable ? "true" : "false"),
                    canMakePayments: \(canMakePayments ? "true" : "false"),
                    requestPayment: function(request) {
                        return new Promise((resolve, reject) => {
                            window.webkit.messageHandlers.applePay.postMessage({
                                action: 'requestPayment',
                                request: request,
                                callbackId: Math.random().toString(36).substring(7)
                            });
                        });
                    }
                };
            }
        """

        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                self.logger.error("Failed to inject Apple Pay support: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Payment Authorization Delegate

private class PaymentAuthorizationDelegate: NSObject, PKPaymentAuthorizationControllerDelegate {
    private let completion: (Result<PKPayment, ApplePayError>) -> Void
    private var payment: PKPayment?

    init(completion: @escaping (Result<PKPayment, ApplePayError>) -> Void) {
        self.completion = completion
        super.init()
    }

    func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didAuthorizePayment payment: PKPayment,
        handler: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        self.payment = payment
        // In production, you'd send this to your payment processor
        // For now, we'll assume success
        handler(PKPaymentAuthorizationResult(status: .success, errors: nil))
    }

    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss {
            if let payment = self.payment {
                self.completion(.success(payment))
            } else {
                self.completion(.failure(.cancelled))
            }
        }
    }

    func presentationWindow(for controller: PKPaymentAuthorizationController) -> NSWindow? {
        return NSApp.mainWindow
    }
}

// MARK: - Apple Pay JS Types

struct ApplePayJSRequest: Codable {
    let countryCode: String?
    let currencyCode: String?
    let lineItems: [ApplePayJSLineItem]
    let total: ApplePayJSLineItem
    let shippingMethods: [ApplePayJSShippingMethod]?
    let requiredBillingContactFields: [String]?
    let requiredShippingContactFields: [String]?
}

struct ApplePayJSLineItem: Codable {
    let label: String
    let amount: String
    let pending: Bool

    init(label: String, amount: String, pending: Bool = false) {
        self.label = label
        self.amount = amount
        self.pending = pending
    }
}

struct ApplePayJSShippingMethod: Codable {
    let identifier: String
    let label: String
    let detail: String?
    let amount: String
}

struct ApplePayJSResponse {
    enum Status {
        case success
        case failure
    }

    let status: Status
    var token: String?
    var error: String?
}

// MARK: - Errors

enum ApplePayError: LocalizedError {
    case notAvailable
    case noCardsConfigured
    case presentationFailed
    case cancelled
    case paymentFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Apple Pay is not available on this device"
        case .noCardsConfigured:
            return "No payment cards configured in Apple Wallet"
        case .presentationFailed:
            return "Could not present Apple Pay sheet"
        case .cancelled:
            return "Payment was cancelled"
        case .paymentFailed(let reason):
            return "Payment failed: \(reason)"
        }
    }
}
