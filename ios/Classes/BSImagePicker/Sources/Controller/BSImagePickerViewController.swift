// The MIT License (MIT)
//
// Copyright (c) 2015 Joakim Gyllström
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import UIKit
import Photos

/**
BSImagePickerViewController.
Use settings or buttons to customize it to your needs.
*/
open class BSImagePickerViewController : UINavigationController , PreviewViewControllerDelegate{
    var assetStore : AssetStore?
    var selectionClosure: ((_ asset: PHAsset) -> Void)?
    var deselectionClosure: ((_ asset: PHAsset) -> Void)?
    var cancelClosure: ((_ assets: [PHAsset]) -> Void)?
    var finishClosure: ((_ assets: [NSDictionary], _ success : Bool, _ error : NSError) -> Void)?
    var selectLimitReachedClosure: ((_ selectionLimit: Int) -> Void)?
    
    /**
     Object that keeps settings for the picker.
     */
    open var settings: BSImagePickerSettings = Settings()
    
    /**
     Default selections
     */
    @objc open var defaultSelections: PHFetchResult<PHAsset>? {
        didSet {
            var selections: [PHAsset] = []
            defaultSelections?.enumerateObjects({ (asset, idx, stop) in
                selections.append(asset)
            })

            self.assetStore = AssetStore(assets: selections)
        }
    }
    
    var originBarButton: SSRadioButton = SSRadioButton(type: .custom)
    var doneBarButton: UIButton = UIButton(type: .custom)
    var bottomContentView : UIView = UIView()
    
    let doneBarButtonTitle: String = NSLocalizedString("Done", comment: "")
    let originBarButtonTitle: String = NSLocalizedString("Origin", comment: "")
    
    /**
     Fetch results.
     */
    @objc open lazy var fetchResults: [PHFetchResult] = { () -> [PHFetchResult<PHAssetCollection>] in
        let fetchOptions = PHFetchOptions()
        // Camera roll fetch result
        let cameraRollResult = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: fetchOptions)
        fetchOptions.predicate = NSPredicate(format: "estimatedAssetCount > 0")
        // Albums fetch result
        let albumResult = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        return [cameraRollResult, albumResult]
    }()
    
    @objc lazy var photosViewController: PhotosViewController = {
        let vc = PhotosViewController(fetchResults: self.fetchResults, assetStore: assetStore ?? AssetStore(assets: []), settings: self.settings)
        return vc
    }()
    
    @objc lazy var previewController: PreviewViewController = {
        let vc = PreviewViewController(nibName: nil, bundle: nil);
        vc.delegate = self
        vc.settings = settings
        if let album = fetchResults.first?.firstObject {
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [
                NSSortDescriptor(key: "creationDate", ascending: true)
            ]
            let fetchResult = PHAsset.fetchAssets(in: album, options: fetchOptions)
            
            let index = fetchResult.index(of: self.assetStore!.assets.first!)
            vc.currentAssetIndex = index
            vc.fetchResult = fetchResult
        }
        return vc
    }()
    
    @objc class func authorize(_ status: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(), fromViewController: UIViewController, completion: @escaping (_ authorized: Bool) -> Void) {
        switch status {
        case .authorized:
            // We are authorized. Run block
            completion(true)
        case .notDetermined:
            // Ask user for permission
            PHPhotoLibrary.requestAuthorization({ (status) -> Void in
                DispatchQueue.main.async(execute: { () -> Void in
                    self.authorize(status, fromViewController: fromViewController, completion: completion)
                })
            })
        default: ()
            DispatchQueue.main.async(execute: { () -> Void in
                completion(false)
            })
        }
    }
    
    /**
    Sets up an classic image picker with results from camera roll and albums
    */
    public init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    /**
    Load view. See apple documentation
    */
    open override func loadView() {
        super.loadView()
        // TODO: Settings
        view.backgroundColor = UIColor.white
        
        // Make sure we really are authorized
        if PHPhotoLibrary.authorizationStatus() == .authorized {
            if assetStore?.count ?? 0 > 0 {
                bottomContentView.frame = self.toolbar.bounds
                bottomContentView.backgroundColor = UIColor.clear
                
                doneBarButton.frame = CGRect(x: 0, y: 0, width: 80, height: 30)
                doneBarButton.backgroundColor = settings.selectionStrokeColor
                doneBarButton.setTitleColor(UIColor.white, for: .normal)
                doneBarButton.setTitleColor(UIColor.gray, for: .disabled)
                doneBarButton.setTitle(doneBarButtonTitle, for: .normal)
                doneBarButton.setBackgroundColor(color: settings.selectionStrokeColor, for: .normal)
                doneBarButton.setBackgroundColor(color: UIColor.darkGray, for: .disabled)
                doneBarButton.layer.masksToBounds = true
                doneBarButton.layer.cornerRadius = 5.0
                doneBarButton.center = CGPoint(x: bottomContentView.bounds.size.width - 40 - 5, y: bottomContentView.bounds.size.height/2.0)
                doneBarButton.addTarget(self, action: #selector(PhotosViewController.doneButtonPressed(_:)), for: .touchUpInside)
                
                originBarButton.frame = CGRect(x: 60, y: 0, width: 100, height: 50)
                originBarButton.setTitle(originBarButtonTitle, for: .normal)
                originBarButton.isSelected = false
                originBarButton.circleRadius = 8.0
                originBarButton.circleColor = settings.selectionStrokeColor
                originBarButton.center = CGPoint(x: bottomContentView.bounds.size.width/2.0, y: bottomContentView.bounds.size.height/2.0)
                originBarButton.addTarget(self, action: #selector(PhotosViewController.originButtonPressed(_:)), for: .touchUpInside)
                
                bottomContentView.addSubview(doneBarButton)
                bottomContentView.addSubview(originBarButton)
                setViewControllers([previewController], animated: false)
            }else {
                photosViewController.selectionClosure = selectionClosure
                photosViewController.deselectionClosure = deselectionClosure
                photosViewController.cancelClosure = cancelClosure
                photosViewController.finishClosure = finishClosure
                photosViewController.selectLimitReachedClosure = selectLimitReachedClosure
                setViewControllers([photosViewController], animated: false)
            }
        }
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if bottomContentView.superview == nil && assetStore?.count ?? 0 > 0 {
            self.setToolbarHidden(false, animated: true)
            self.toolbar.layoutIfNeeded()
            bottomContentView.frame = self.toolbar.bounds
            doneBarButton.center = CGPoint(x: bottomContentView.bounds.size.width - 40 - 5, y: bottomContentView.bounds.size.height/2.0)
            originBarButton.center = CGPoint(x: bottomContentView.bounds.size.width/2.0, y: bottomContentView.bounds.size.height/2.0)
            self.toolbar.addSubview(bottomContentView)
            updateDoneButton()
        }
    }
    
    func previewViewControllerDidSelectImageItem(_ asset : PHAsset) -> Int {
        if self.assetStore?.contains(asset) ?? false {
            self.assetStore?.remove(asset)
            deselectionClosure?(asset)
            updateDoneButton()
            return -1
        } else if self.assetStore?.count ?? 100 < settings.maxNumberOfSelections {
            self.assetStore?.append(asset)
            selectionClosure?(asset)
            updateDoneButton()
            return self.assetStore?.count ?? 0
        }
        return -1
    }
    
    func previewViewControllerIsSelectImageItem(_ asset : PHAsset) -> Int {
        return (assetStore?.assets.firstIndex(of: asset) ?? -1) + 1
    }
    
    func previewViewControllerCanSelectImageItem(_ asset : PHAsset) -> NSError? {
        if assetStore?.contains(asset) ?? false {
            return nil
        }else if asset.mediaType == .video, assetStore?.isContainPic() ?? false {
            return NSError(domain: "不能同时选择图片和视频", code: 1, userInfo: nil)
        }else if asset.mediaType == .video, assetStore?.count ?? 100 > 0 {
            return NSError(domain: "一次只能选择一个视频", code: 2, userInfo: nil)
        }else if asset.mediaType == .video , asset.duration > 61 {
            return NSError(domain: "请选择60秒以下的视频", code: 3, userInfo: nil)
        }else if asset.mediaType == .image, assetStore?.isContainVideo() ?? false {
            return NSError(domain: "不能同时选择图片和视频", code: 4, userInfo: nil)
        }else if assetStore?.count ?? 100 >= settings.maxNumberOfSelections {
            selectLimitReachedClosure?(assetStore?.count ?? 0)
            return NSError(domain: "图片选择数量超过最大限制", code: 5, userInfo: nil)
        }else if let fileName = asset.value(forKey: "filename"), (fileName as! String).hasSuffix("GIF"), asset.fileSize > 1024 * 1024 * 8.0 {
            return NSError(domain: "发送的GIF图片大小不能超过8M", code: 6, userInfo: nil)
        }
        return nil
    }
    
    @objc func doneButtonPressed(_ sender: UIButton) {
        weak var weakSelf = self
        let maxWidth = settings.maxWidthOfImage
        let maxHeight = settings.maxHeightOfImage
        let quality = settings.qualityOfThumb
        let thumb = !originBarButton.isSelected
        let assets = self.assetStore!.assets
        doneBarButton.isEnabled = false
        
        weak var hud = MBProgressHUD.showAdded(to: self.view, animated: true)
        hud?.label.text = originBarButton.isSelected ? NSLocalizedString("拷贝中", comment: "") : NSLocalizedString("压缩中", comment: "")
        hud?.bezelView.backgroundColor = UIColor.darkGray
        DispatchQueue.global().async {
            let thumbDir = (NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last ?? NSTemporaryDirectory()) + "/multi_image_pick/thumb/"
            if !FileManager.default.fileExists(atPath: thumbDir) {
                do {
                    try FileManager.default.createDirectory(atPath: thumbDir, withIntermediateDirectories: true, attributes: nil)
                }catch{
                    print(error)
                }
            }
            var results = [NSDictionary]();
            var error = NSError()
            for asset in assets {
                var compressing = true
                asset.compressAsset(maxWidth, maxHeight: maxHeight, quality: quality, thumb: thumb, saveDir: thumbDir, process: { (process) in
                    
                }, failed: { (err) in
                    error = err
                    compressing = false
                }) { (info) in
                    results.append(info)
                    compressing = false
                }
                while compressing {
                    usleep(50000)
                }
            }
            
            DispatchQueue.main.async {
                weakSelf?.doneBarButton.isEnabled = true
                hud?.hide(animated: true)
                weakSelf?.finishClosure?(results, assets.count == results.count, error)
                weakSelf?.dismiss(animated: true, completion: nil)
            }
        }
        
    }
    
    @objc func originButtonPressed(_ sender: UIButton) {
        originBarButton.isSelected = !originBarButton.isSelected
    }
    
    func updateDoneButton() {
        if self.assetStore?.assets.count ?? 0 > 0 {
            doneBarButton.setTitle("\(doneBarButtonTitle)(\(self.assetStore?.count ?? 0))", for: .normal)
            var width : CGFloat = 90.0
            switch settings.maxNumberOfSelections {
            case 0..<10:
                width = 90.0
            case 10..<100:
                width = 110.0
            case 100..<1000:
                width = 140.0
            default:
                width = 90.0
            }
            if width != doneBarButton.frame.size.width {
                doneBarButton.frame = CGRect(x: 0, y: 0, width: width, height: 30)
                doneBarButton.center = CGPoint(x: self.toolbar.bounds.size.width - width/2 - 10, y: self.toolbar.bounds.size.height/2.0)
            }
        } else {
            doneBarButton.setTitle(doneBarButtonTitle, for: .normal)
            if 60 != doneBarButton.frame.size.width {
                doneBarButton.frame = CGRect(x: 0, y: 0, width: 60, height: 30)
                doneBarButton.center = CGPoint(x: self.toolbar.bounds.size.width - 40, y: self.toolbar.bounds.size.height/2.0)
            }
        }

        doneBarButton.isEnabled = self.assetStore?.assets.count ?? 0 > 0
    }
}

// MARK: ImagePickerSettings proxy
extension BSImagePickerViewController: BSImagePickerSettings {
    /**
     See BSImagePicketSettings for documentation
     */
    @objc public var maxHeightOfImage: Int {
        get {
            return settings.maxHeightOfImage
        }
        set {
            settings.maxHeightOfImage = newValue
        }
    }
    /**
     See BSImagePicketSettings for documentation
     */
    @objc public var maxWidthOfImage: Int {
        get {
            return settings.maxWidthOfImage
        }
        set {
            settings.maxWidthOfImage = newValue
        }
    }
    /**
     See BSImagePicketSettings for documentation
     */
    @objc public var qualityOfThumb: CGFloat {
        get {
            return settings.qualityOfThumb
        }
        set {
            settings.qualityOfThumb = newValue
        }
    }

    /**
     See BSImagePicketSettings for documentation
     */
    @objc public var maxNumberOfSelections: Int {
        get {
            return settings.maxNumberOfSelections
        }
        set {
            settings.maxNumberOfSelections = newValue
        }
    }
    
    /**
     See BSImagePicketSettings for documentation
     */
    public var selectionCharacter: Character? {
        get {
            return settings.selectionCharacter
        }
        set {
            settings.selectionCharacter = newValue
        }
    }
    
    /**
     See BSImagePicketSettings for documentation
     */
    @objc public var selectionFillColor: UIColor {
        get {
            return settings.selectionFillColor
        }
        set {
            settings.selectionFillColor = newValue
        }
    }
    
    /**
     See BSImagePicketSettings for documentation
     */
    @objc public var selectionStrokeColor: UIColor {
        get {
            return settings.selectionStrokeColor
        }
        set {
            settings.selectionStrokeColor = newValue
        }
    }
    
    /**
     See BSImagePicketSettings for documentation
     */
    @objc public var selectionTextAttributes: [NSAttributedString.Key: AnyObject] {
        get {
            return settings.selectionTextAttributes
        }
        set {
            settings.selectionTextAttributes = newValue
        }
    }
    
    /**
     See BSImagePicketSettings for documentation
     */
    @objc public var cellsPerRow: (_ verticalSize: UIUserInterfaceSizeClass, _ horizontalSize: UIUserInterfaceSizeClass) -> Int {
        get {
            return settings.cellsPerRow
        }
        set {
            settings.cellsPerRow = newValue
        }
    }
    
}
