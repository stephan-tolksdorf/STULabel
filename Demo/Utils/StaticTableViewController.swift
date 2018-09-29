// Copyright 2018 Stephan Tolksdorf

class StaticTableViewController : UITableViewController {
  var cells = [UITableViewCell]() {
    didSet {
      tableView.reloadData()
    }
  }

  override init(style: UITableViewStyle = .plain) {
    super.init(style: style)
    if #available(iOS 11, tvOS 11, *) {}
    else {
      tableView.estimatedRowHeight = 57.5
    }
  }

  @available(*, unavailable)
  required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.alwaysBounceVertical = false
  }

  var shouldUpdatePreferredContentSize: Bool = false
  var minPreferredContentWidth: CGFloat = 0

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    if shouldUpdatePreferredContentSize {
      let size = tableView.contentSize
      preferredContentSize = CGSize(width: max(size.width, minPreferredContentWidth),
                                    height: size.height)
    }
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return section == 0 ? cells.count : 0
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)
             -> UITableViewCell
  {
    return cells[indexPath.row]
  }
}
