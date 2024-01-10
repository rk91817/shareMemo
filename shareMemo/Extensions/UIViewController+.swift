import Foundation
import UIKit

extension UIViewController {
    // memoServiceから通知を受け取った時の処理
    func setupMemoServiceErrorHandlers(memoService: MemoService?) {
        guard let memoService = memoService else { return }
        memoService.errorDidOccur = { [weak self] error, managerType in
            // ビューがメモリにロードされているか、アクティブかを確認
            guard let strongSelf = self, strongSelf.isViewLoaded, strongSelf.view.window != nil else { return }
            strongSelf.showErrorAlert(error: error, memoService: memoService, managerType: managerType)
        }
    }
    
    func showErrorAlert(error: Error, memoService: MemoService, managerType: ManagerType) {
        let title: String
        let message: String
        let nsError = error as NSError
        let result = memoService.getErrorMessageAndTitle(error: nsError, managerType: managerType)
        title = result.title
        message = result.message
        
        let okAction = UIAlertAction(title: AlertActionTitle.ok, style: .default, handler: nil)
        DispatchQueue.main.async {
            self.showAlert(title: title, message: message, actions: [okAction])
        }
    }
    
    func showAlert(title: String,
                   message: String,
                   preferredStyle: UIAlertController.Style = .alert,
                   actions: [UIAlertAction]) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: preferredStyle)
        for action in actions {
            alertController.addAction(action)
        }
        present(alertController, animated: true, completion: nil)
    }
}
