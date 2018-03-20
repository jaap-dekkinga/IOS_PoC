//
//  MainViewController.swift
//  AudioTriggerPOC
//
//  Created by Aleksandar Mihailovski on 2018-01-30.
//  Copyright © 2018 Aleksandar Mihailovski. All rights reserved.
//

import UIKit

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
        let sample = sampleDataManager.samples[indexPath.row]
        cell.textLabel?.text = sample.title
        cell.detailTextLabel?.text = sample.desc
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sampleDataManager.samples.count
    }
}

extension MainViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let sample = sampleDataManager.samples[indexPath.row]
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
