import UIKit

class ViewController: UIViewController {

    var signatureView: HYPSignatureView?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = UIColor.whiteColor()
        self.view.userInteractionEnabled = true

        signatureView = HYPSignatureView(frame: self.view.frame, context: nil)
        self.view.addSubview(signatureView!)
    }
}

