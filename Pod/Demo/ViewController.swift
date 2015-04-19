import UIKit

class ViewController: UIViewController {

    var signatureView: HYPSignatureView?

    override func viewDidLoad() {
        super.viewDidLoad()

        signatureView = HYPSignatureView(frame: self.view.frame)
        self.view.addSubview(signatureView!)
    }
}

