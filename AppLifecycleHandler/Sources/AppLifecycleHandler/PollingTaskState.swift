actor PollingTaskState {
    private var task: Task<Void, Never>?

    func replace(with newTask: Task<Void, Never>) -> Task<Void, Never>? {
        let previous = self.task
        self.task = newTask
        return previous
    }

    func take() -> Task<Void, Never>? {
        let current = self.task
        self.task = nil
        return current
    }
}
