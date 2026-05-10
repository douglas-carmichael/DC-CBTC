import TermKit

func testColors() {
    let _ = ColorScheme(normal: Attribute(fg: .cyan, bg: .black),
                        focus: Attribute(fg: .cyan, bg: .black),
                        hotNormal: Attribute(fg: .cyan, bg: .black),
                        hotFocus: Attribute(fg: .cyan, bg: .black))
}
