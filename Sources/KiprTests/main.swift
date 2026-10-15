import KiprCore

let items = [PickerItem(title: "Terminal"), PickerItem(title: "Safari"), PickerItem(title: "Wallpaper")]
assert(PickerLogic.filtered(items, query: "all") == [items[2]])
assert(PickerLogic.filtered(items, query: "  term ") == [items[0]])
assert(PickerLogic.moveSelection(current: 0, offset: -1, count: 3) == 2)
assert(PickerLogic.moveSelection(current: 2, offset: 1, count: 3) == 0)
print("KiprCore checks passed")

import CoreGraphics
let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
let size = CGSize(width: 100, height: 100)
assert(WindowLayout.frame(for: .maximize, in: screen, gap: 0, windowSize: size) == screen)
assert(WindowLayout.frame(for: .maximize, in: screen, gap: 10, windowSize: size) == CGRect(x: 10, y: 10, width: 980, height: 780))
assert(WindowLayout.frame(for: .leftHalf, in: screen, gap: 10, windowSize: size) == CGRect(x: 10, y: 10, width: 485, height: 780))
let l = WindowLayout.frame(for: .leftHalf, in: screen, gap: 10, windowSize: size)
let r = WindowLayout.frame(for: .rightHalf, in: screen, gap: 10, windowSize: size)
assert(r.minX - l.maxX == 10 && r.maxX == 990)
let br = WindowLayout.frame(for: .bottomRight, in: screen, gap: 0, windowSize: size)
assert(br == CGRect(x: 500, y: 400, width: 500, height: 400))
assert(WindowLayout.frame(for: .center, in: screen, gap: 0, windowSize: size) == CGRect(x: 450, y: 350, width: 100, height: 100))
print("WindowLayout checks passed")
