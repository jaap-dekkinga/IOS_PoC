//
//  MainViewController.swift
//  AudioTriggerPOC
//
//  Created by Aleksandar Mihailovski on 2018-01-30.
//  Copyright © 2018 Aleksandar Mihailovski. All rights reserved.
//

import UIKit

protocol SampleableData {
    var title: String { get }
    var desc: String { get }
    func prettyDescription() -> String
}

class MainViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!

    fileprivate let sampleDataManager = SampleDataManager()

    override func viewDidLoad() {
        super.viewDidLoad()

        SampleDataManager.delegate = self
    }
}

extension MainViewController: SampleDataManagerDelegate {
    func didChange() {
        self.tableView.reloadData()
    }
}

extension MainViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "SampleDataManager")
        let sample = sampleDataManager.sampleResults[indexPath.row] as SampleableData
        cell.textLabel?.text = sample.title
        cell.detailTextLabel?.text = sample.desc
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sampleDataManager.sampleResults.count
    }
}

extension MainViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let sample = sampleDataManager.sampleResults[indexPath.row] as SampleableData
        let showDetailsVC = SampleDetailsViewController.create(for: sample)
        navigationController?.pushViewController(showDetailsVC, animated: true)
        tableView.deselectRow(at: indexPath, animated: false)
    }

    public func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
//            let sample = sampleDataManager.samples[indexPath.row]
//            sampleDataManager.remove(sample)

            sampleDataManager.remove(ix: indexPath.row)
        }
    }
}

extension SampleResult: SampleableData {
    var title: String {
        switch self {
        case .success(let value):
            return value.title
        case .failure(_):
            return "unknown"
        }
    }

    var desc: String {
        switch self {
        case .success(let value):
            return value.desc
        case .failure(let error):
            return error.desc
        }
    }

    func prettyDescription() -> String {
        switch self {
        case .success(let value):
            return value.prettyDescription()
        case .failure(let error):
            return "error: " + error.desc + " " + String(error.code)
        }
    }
}
