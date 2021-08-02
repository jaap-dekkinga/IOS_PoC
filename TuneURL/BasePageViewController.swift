//
//  BasePageViewController.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 8/25/20.
//  Copyright © 2020-2021 TuneURL Inc. All rights reserved.
//


import UIKit


final class BasePageViewController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {

	// private
	private var pageControl = UIPageControl()
	private var pageControllers = [UIViewController]()

	// MARK: -
	// MARK: UIViewController

	override func viewDidLoad()
	{
		super.viewDidLoad()

		self.dataSource = self
		self.delegate = self

		// setup the page view controllers
		let storyboard = UIStoryboard(name: "Main", bundle: nil)
		pageControllers.append(storyboard.instantiateViewController(withIdentifier: "ListenViewController"))
		pageControllers.append(storyboard.instantiateViewController(withIdentifier: "SavedContentViewController"))
		self.setViewControllers([pageControllers[0]], direction: .forward, animated: false)

		// setup the page control
		let bounds = self.view.bounds
		pageControl.frame = CGRect(x: 0, y: (bounds.maxY - 50), width: bounds.width, height: 50)
		pageControl.numberOfPages = pageControllers.count
		pageControl.currentPage = 0
		self.view.addSubview(pageControl)
	}

	// MARK: -
	// MARK: UIPageViewControllerDataSource

	func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController?
	{
		guard let currentIndex = pageControllers.firstIndex(of: viewController) else {
			return nil
		}

		let newIndex = (currentIndex - 1)
		guard (newIndex >= 0) else {
			return nil
		}

		return pageControllers[newIndex]
	}

	func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController?
	{
		guard let currentIndex = pageControllers.firstIndex(of: viewController) else {
			return nil
		}

		let newIndex = (currentIndex + 1)
		guard (newIndex < pageControllers.count) else {
			return nil
		}

		return pageControllers[newIndex]
	}

	// MARK: -
	// MARK: UIPageViewControllerDelegate

	func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool)
	{
		// get the index of the view controller
		guard let viewControllers = pageViewController.viewControllers,
			(viewControllers.count == 1),
			let pageIndex = pageControllers.firstIndex(of: viewControllers[0]) else {
			return
		}

		pageControl.currentPage = pageIndex
	}

}
