// Copyright 2018 Stephan Tolksdorf

import UIKit

import STULabel

class RootViewController : UITableViewController {

  init() {
    super.init(style: .plain)
    self.navigationItem.title = "STULabel"
    self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: nil, action: nil)
    self.tableView.register(Cell.self, forCellReuseIdentifier: Cell.reuseIdentifier)
    self.sections = [Section(title: "Tests",
                             items: [Item(title: "UDHR Viewer",      vc: UDHRViewerVC.self),
                                     Item(title: "Tap to read more", vc: TapToReadMoreVC.self)]),
                    Section(title: "Performance",
                             items: [Item(title: "UITableView scrolling",
                                          vc: TableViewPerformanceVC.self),
                                     Item(title: "Label performance",
                                          vc: LabelPerformanceVC.self),
                                     Item(title: "TextFrame performance",
                                          vc: TextFramePerformanceVC.self)])]

  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }


  struct Item {
    let title: String
    let vc: UIViewController.Type
  }

  struct Section {
    let title: String
    let items: [Item]
  }

  class Cell : UITableViewCell {
    static let reuseIdentifier = "cell"
  }

  var sections: [Section] = []

  func section_item(at indexPath: IndexPath) -> (section: Section, item: Item) {
    let section = sections[indexPath.section]
    let item = section.items[indexPath.item]
    return (section, item)
  }
  func item(at indexPath: IndexPath) -> Item {
    return section_item(at: indexPath).item
  }

  override func numberOfSections(in tableView: UITableView) -> Int { return sections.count }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return sections[section].items.count
  }

  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int)
             -> String?
  {
    return sections[section].title
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)
             -> UITableViewCell
  {
    let cell = tableView.dequeueReusableCell(withIdentifier: Cell.reuseIdentifier, for: indexPath)
    cell.textLabel!.text = sections[indexPath.section].items[indexPath.item].title
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let item = self.item(at: indexPath)
    self.navigationController?.pushViewController(item.vc.init(), animated: true)
  }



}
