import SwiftUI

/// O SDK do macOS 27 declara `@State` também como macro, e o plugin dela (SwiftUIMacros)
/// só vem com o Xcode. Este apelido aponta para o property wrapper, que compila só com
/// o Command Line Tools.
typealias ViewState<Value> = SwiftUI.State<Value>
