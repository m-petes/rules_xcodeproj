import ArgumentParser

enum AutogenerationMode: String, ExpressibleByArgument {
    case auto
    case all
    case none
}
