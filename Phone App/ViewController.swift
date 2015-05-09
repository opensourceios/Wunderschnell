//
//  ViewController.swift
//  WatchButton
//
//  Created by Boris Bügling on 09/05/15.
//  Copyright (c) 2015 Boris Bügling. All rights reserved.
//

import Alamofire
import Keys
import UIKit

class ViewController: UIViewController, PayPalFuturePaymentDelegate {
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var productImageView: UIImageView!

    private var payPalConfiguration: PayPalConfiguration!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Not that pretty -- but that way we localized the Sphere.IO interactions for now
        if let delegate = UIApplication.sharedApplication().delegate as? AppDelegate {
            delegate.fetchSelectedProduct() {
                if let productData = delegate.selectedProduct {
                    let product = Product(data: productData)

                    self.descriptionLabel.text = product.description
                    self.nameLabel.text = product.name

                    if let amount = product.price["amount"], currency = product.price["currency"] {
                        let actualAmount = Float(amount.toInt()!) / 100.0
                        self.priceLabel.text = "\(actualAmount) \(currency)"
                    }

                    Alamofire.request(.GET, product.imageUrl).response() { (_, _, data, error) in
                        if let data = data as? NSData {
                            self.productImageView.image = UIImage(data: data)
                        }
                    }
                }
                return
            }
        }
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        PayPalMobile.preconnectWithEnvironment(PayPalEnvironmentSandbox)
    }

    // MARK: - Actions

    @IBAction func setUpPaymentTapped(sender: UIBarButtonItem) {
        payPalConfiguration = PayPalConfiguration()

        payPalConfiguration.merchantName = "Ultramagnetic Omega Supreme"
        payPalConfiguration.merchantPrivacyPolicyURL = NSURL(string:"https://www.omega.supreme.example/privacy")
        payPalConfiguration.merchantUserAgreementURL = NSURL(string:"https://www.omega.supreme.example/user_agreement")

        let vc = PayPalFuturePaymentViewController(configuration: payPalConfiguration, delegate: self)
        presentViewController(vc, animated: true, completion: nil)
    }

    // MARK: - PayPalFuturePaymentDelegate

    func payPalFuturePaymentDidCancel(futurePaymentViewController: PayPalFuturePaymentViewController!) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }

    func payPalFuturePaymentViewController(futurePaymentViewController: PayPalFuturePaymentViewController!, didAuthorizeFuturePayment futurePaymentAuthorization: [NSObject : AnyObject]!) {
        if let futurePaymentAuthorization = futurePaymentAuthorization {
            let clientMetadataId = PayPalMobile.clientMetadataID()

            if let response = futurePaymentAuthorization["response"] as? [String:AnyObject], code = response["code"] as? String {
                let keys = WatchButtonKeys()
                let client = PayPalClient(clientId: keys.payPalSandboxClientId(), clientSecret: keys.payPalSandboxClientSecret(), futurePaymentCode: code, metadataId: clientMetadataId)

                if let delegate = UIApplication.sharedApplication().delegate as? AppDelegate, productData = delegate.selectedProduct {
                    let product = Product(data: productData)

                    if let amount = product.price["amount"], currency = product.price["currency"] {
                        client.createPayment(product.name, currency, amount) { (paymentId) in
                            storePaymentId(paymentId)
                            storeRefreshToken(client.refreshToken!)
                            NSLog("Stored payment ID \(paymentId) in keychain.")

                            // Not that pretty, but allows us to skip a second OAuth flow
                            delegate.client = client
                        }
                    }
                }
            }
        }

        self.dismissViewControllerAnimated(true, completion: nil)
    }
}
