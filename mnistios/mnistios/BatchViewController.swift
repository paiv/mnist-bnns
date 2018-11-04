//
//  BatchViewController.swift
//  mnistios
//
//  Created by Pavel Ivashkov on 2016-09-24.
//  Copyright © 2016 paiv. All rights reserved.
//

import UIKit


fileprivate protocol ViewModelDelegate : class {
    func viewModelDidStartBatching(viewModel: ViewModel)
    func viewModelDidFinishBatching(viewModel: ViewModel)
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
    
    func runPredictions(indexes: [Int]) {
        
        delegate?.viewModelDidStartBatching(viewModel: self)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let this = self else { return }
            
            let samples = this.dataset.samples
            var predictions: [Int: Int] = [:]
            
            let preds = this.ai.predictBatch(images: samples.samples(indexes: indexes), count: indexes.count)
            
            for (index, value) in preds.enumerated() {
                predictions[indexes[index]] = value
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let this = self else { return }
                
                for (k,v) in predictions {
                    this.predictions[k] = v
                }
                
                this.delegate?.viewModelDidFinishBatching(viewModel: this)
            }
        }
    }
}


class BatchViewController: UICollectionViewController {

    fileprivate var viewModel: ViewModel!
    
    var predictButton: UIBarButtonItem!
    var spinnerButton: UIBarButtonItem!
    weak var spinner: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView?.register(UINib(nibName: "ImageCell", bundle: nil), forCellWithReuseIdentifier: "someCell")
        
        let predictButton = UIBarButtonItem(title: "Batch", style: .plain, target: self, action: #selector(handlePredictButton))
        navigationItem.rightBarButtonItem = predictButton
        self.predictButton = predictButton
        
        let spinner = UIActivityIndicatorView(style: .gray)
        self.spinner = spinner
        let spinnerButton = UIBarButtonItem(customView: spinner)
        self.spinnerButton = spinnerButton
        
        viewModel = ViewModel()
        viewModel.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        collectionView?.flashScrollIndicators()
    }
    
    @objc private func handlePredictButton(sender: AnyObject!) {
        guard let indexPaths = collectionView?.indexPathsForVisibleItems else { return }
        
        viewModel.runPredictions(indexes: indexPaths.map{$0.row})
    }
}


extension BatchViewController {
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


extension BatchViewController : ViewModelDelegate {

    fileprivate func viewModelDidStartBatching(viewModel: ViewModel) {
        navigationItem.rightBarButtonItem = spinnerButton
        spinner.startAnimating()
    }
    
    fileprivate func viewModelDidFinishBatching(viewModel: ViewModel) {
        spinner.stopAnimating()
        navigationItem.rightBarButtonItem = predictButton
        collectionView?.reloadData()
    }
}
