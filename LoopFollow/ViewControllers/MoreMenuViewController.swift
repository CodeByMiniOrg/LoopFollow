// LoopFollow
// MoreMenuViewController.swift

import SwiftUI
import UIKit

class MoreMenuViewController: UIViewController {
    private var tableView: UITableView!

    struct MenuItem {
        let title: String
        let icon: String
        let action: () -> Void
    }

    private var menuItems: [MenuItem] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "More"
        view.backgroundColor = .systemBackground

        // Apply dark mode if needed
        if Storage.shared.forceDarkMode.value {
            overrideUserInterfaceStyle = .dark
        }

        setupTableView()
        updateMenuItems()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateMenuItems()
        tableView.reloadData()
        Observable.shared.settingsPath.set(NavigationPath())
    }

    private func setupTableView() {
        tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func updateMenuItems() {
        menuItems = []

        // Get items that are in the "more" menu
        let itemsInMore = Storage.shared.itemsInMore()

        // Always add Settings first if it's in More
        if itemsInMore.contains(.settings) {
            menuItems.append(MenuItem(
                title: TabItem.settings.displayName,
                icon: TabItem.settings.icon,
                action: { [weak self] in
                    self?.openSettings()
                }
            ))
        }

        // Add remaining items (excluding Settings which was already added)
        for item in itemsInMore where item != .settings {
            menuItems.append(MenuItem(
                title: item.displayName,
                icon: item.icon,
                action: { [weak self] in
                    self?.openItem(item)
                }
            ))
        }
    }

    private func openItem(_ item: TabItem) {
        switch item {
        case .home:
            // Home should not be in More menu, but handle gracefully
            break
        case .alarms:
            openAlarms()
        case .remote:
            openRemote()
        case .nightscout:
            openNightscout()
        case .snoozer:
            openSnoozer()
        case .settings:
            openSettings()
        }
    }

    private func openSettings() {
        let settingsVC = UIHostingController(rootView: SettingsMenuView())
        let navController = UINavigationController(rootViewController: settingsVC)

        // Apply dark mode if needed
        if Storage.shared.forceDarkMode.value {
            settingsVC.overrideUserInterfaceStyle = .dark
            navController.overrideUserInterfaceStyle = .dark
        }

        // Add a close button
        settingsVC.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissModal)
        )

        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }

    private func openAlarms() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let alarmsVC = storyboard.instantiateViewController(withIdentifier: "AlarmViewController")
        let navController = UINavigationController(rootViewController: alarmsVC)

        // Apply dark mode if needed
        if Storage.shared.forceDarkMode.value {
            alarmsVC.overrideUserInterfaceStyle = .dark
            navController.overrideUserInterfaceStyle = .dark
        }

        // Add a close button
        alarmsVC.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissModal)
        )

        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }

    private func openRemote() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let remoteVC = storyboard.instantiateViewController(withIdentifier: "RemoteViewController")
        let navController = UINavigationController(rootViewController: remoteVC)

        // Apply dark mode if needed
        if Storage.shared.forceDarkMode.value {
            remoteVC.overrideUserInterfaceStyle = .dark
            navController.overrideUserInterfaceStyle = .dark
        }

        // Add a close button
        remoteVC.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissModal)
        )

        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }

    private func openNightscout() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let nightscoutVC = storyboard.instantiateViewController(withIdentifier: "NightscoutViewController")
        let navController = UINavigationController(rootViewController: nightscoutVC)

        // Apply dark mode if needed
        if Storage.shared.forceDarkMode.value {
            nightscoutVC.overrideUserInterfaceStyle = .dark
            navController.overrideUserInterfaceStyle = .dark
        }

        // Add a close button
        nightscoutVC.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissModal)
        )

        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }

    private func openSnoozer() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let snoozerVC = storyboard.instantiateViewController(withIdentifier: "SnoozerViewController")
        let navController = UINavigationController(rootViewController: snoozerVC)

        // Apply dark mode if needed
        if Storage.shared.forceDarkMode.value {
            snoozerVC.overrideUserInterfaceStyle = .dark
            navController.overrideUserInterfaceStyle = .dark
        }

        // Add a close button
        snoozerVC.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissModal)
        )

        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }

    @objc private func dismissModal() {
        dismiss(animated: true)
    }
}

extension MoreMenuViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return menuItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let item = menuItems[indexPath.row]

        var config = cell.defaultContentConfiguration()
        config.text = item.title
        config.image = UIImage(systemName: item.icon)
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        menuItems[indexPath.row].action()
    }
}
