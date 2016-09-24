//
//  OneByOneViewController.swift
//  mnistios
//
//  Created by Pavel Ivashkov on 2016-08-28.
//  Copyright © 2016 paiv. All rights reserved.
//

import UIKit


fileprivate protocol ViewModelDelegate : class {
    func viewModel(viewModel: ViewModel, didPredict label: String, for index: Int)
}


fileprivate class ViewModel {

    let dataset = MnistDataset()
    let ai = MnistNet()
    var predictions: [Int: Int] = [:]

    weak var delegate: ViewModelDelegate?

    var count: Int {
        get {
            return dataset.labels.count
        }
    }
    
    func image(for index: Int) -> UIImage {
        switch predictions[index] {
        case let .some(predictedLabel):
            let matched = dataset.labels.label(index: index) == predictedLabel
            if !matched {
                let img = dataset.samples.transparentImage(index: index)
                return img.withRenderingMode(.alwaysTemplate)
            }
            else {
                return dataset.samples.invertedImage(index: index)
            }
        case .none:
            return dataset.samples.image(index: index)
        }
    }
    
    func label(for index: Int) -> String {
        return String(dataset.labels.label(index: index))
    }
    
    func predictedLabel(for index: Int) -> String? {
        guard let label = predictions[index] else { return nil }
        return String(label)
    }
    
    func predictLabel(for index: Int) {
        let label = ai.predict(image: dataset.samples.sample(index: index))
        predictions[index] = label
        
        delegate?.viewModel(viewModel: self, didPredict: String(label), for: index)
    }
}


class OneByOneViewController: UICollectionViewController {

    fileprivate var viewModel: ViewModel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView?.register(UINib(nibName: "ImageCell", bundle: nil), forCellWithReuseIdentifier: "someCell")
        
        viewModel = ViewModel()
        viewModel.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        collectionView?.flashScrollIndicators()
    }
}


extension OneByOneViewController {
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "someCell", for: indexPath) as! ImageCell

        let image = viewModel.image(for: indexPath.row)
        let label = viewModel.label(for: indexPath.row)
        let predictedLabel = viewModel.predictedLabel(for: indexPath.row)
        
        cell.index = "#\(indexPath.row)"
        cell.image = image
        cell.title = label
        cell.subtitle = predictedLabel
        
        return cell
    }
}


extension OneByOneViewController {
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        viewModel.predictLabel(for: indexPath.row)
    }
}


extension OneByOneViewController : ViewModelDelegate {
    
    fileprivate func viewModel(viewModel: ViewModel, didPredict label: String, for index: Int) {
        collectionView?.reloadItems(at: [IndexPath(row: index, section: 0)])
    }
}
