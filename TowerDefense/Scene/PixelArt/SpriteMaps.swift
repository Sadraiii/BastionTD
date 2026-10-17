import Foundation

/// Hand-drawn pixel sprites. Characters map to colors via `Pal.chars`;
/// "." is transparent. Outlines are added in code, so maps only hold fills.
enum SpriteMaps {
    // MARK: Enemies (two animation frames each)

    static func enemyFrames(_ kind: EnemyKind) -> [[String]] {
        switch kind {
        case .drone: [drone(thrust: "n"), drone(thrust: "O")]
        case .runner: [runner(legs: ".o.o...o.o."), runner(legs: "o..o...o..o")]
        case .brute: [brute(step: false), brute(step: true)]
        case .medic: [medic(feet: "...h...h..."), medic(feet: "....h.h....")]
        case .wisp: [wispUp, wispDown]
        case .splitter: [splitter(feet: "..u.....u.."), splitter(feet: "...u...u...")]
        case .shardling: [shard(legs: "..b.b.."), shard(legs: ".b...b.")]
        case .berserker: [berserker(step: false), berserker(step: true)]
        case .phantom: [phantom(sway: false), phantom(sway: true)]
        case .hexer: [hexer(feet: "..uu...uu.."), hexer(feet: "...uu.uu...")]
        case .titan: [titan(step: false), titan(step: true)]
        case .overlord: [overlord(step: false), overlord(step: true)]
        }
    }

    private static func berserker(step: Bool) -> [String] {
        [
            "..o.......o..",
            "..oo.....oo..",
            "...oRRRRRo...",
            "..RRRRRRRRR..",
            ".RRKYRRRYKRR.",
            ".RRRRRRRRRRR.",
            ".RRrXXXXXrRR.",
            "OORRRRRRRRROO",
            "OO.RRRRRRR.OO",
            "...rrrrrrr...",
            step ? "....uu.uu...." : "...uu...uu...",
            step ? "...uuu.uuu..." : "..uuu...uuu..",
        ]
    }

    private static func phantom(sway: Bool) -> [String] {
        [
            "...wwwww...",
            "..wwwwwww..",
            ".wwNNNNNww.",
            ".wNCNNNCNw.",
            ".wNNNNNNNw.",
            ".wwNNNNNww.",
            ".wwwwwwwww.",
            "wwwwwwwwwww",
            "wwswwwwwsww",
            "wwwwwwwwwww",
            sway ? ".ww.www.ww." : "w.ww.w.ww.w",
            sway ? ".w..w.w..w." : "..w..w..w..",
        ]
    }

    private static func hexer(feet: String) -> [String] {
        [
            "....ppp....",
            "...ppppp...",
            "..ppPPPpp..",
            "..pPYPYPp..",
            "..ppPPPpp..",
            ".ppPPPPPpp.",
            ".pPPPfPPPp.",
            "pPPPPfPPPPp",
            "pPPPPPPPPPp",
            ".pPPPPPPPp.",
            "..ppppppp..",
            feet,
        ]
    }

    private static func overlord(step: Bool) -> [String] {
        [
            "......NNNNNNNN......",
            ".....NnnnnnnnnN.....",
            "....NnnnnnnnnnnN....",
            "....NnGGGGGGGGnN....",
            "....NnGWGGGGWGnN....",
            "....NnnnnnnnnnnN....",
            ".....NnnnnnnnnN.....",
            "...ppppNNNNNNpppp...",
            "..pppPPnnnnnnPPppp..",
            ".ppPPPnnnYYnnnPPPpp.",
            ".pPPPnnnYyyYnnnPPPp.",
            "ppPPPnnnnYYnnnnPPPpp",
            "pPPPPnnnnnnnnnnPPPPp",
            "pPPPPNnnnnnnnnNPPPPp",
            "pPPP.NnnnnnnnnN.PPPp",
            "pPP..NNNNNNNNNN..PPp",
            step ? "pp....NNN..NNN....pp" : "pp...NNN....NNN...pp",
            step ? "p.....NNN..NNN.....p" : "p....NNN....NNN....p",
            step ? "......nnn..nnn......" : ".....nnn....nnn.....",
        ]
    }

    private static func drone(thrust: Character) -> [String] {
        [
            "....y....",
            "....n....",
            "..RRRRR..",
            ".RRWWWRR.",
            ".RWWKWWr.",
            ".RRWWWRr.",
            "..rrrrr..",
            "..\(thrust)...\(thrust)..",
        ]
    }

    private static func runner(legs: String) -> [String] {
        [
            "..y.....y..",
            "...y...y...",
            "...YYYYY...",
            "..YyYYYyY..",
            ".YYKYYYKYY.",
            ".YYYYYYYYY.",
            "..oYYYYYo..",
            legs,
        ]
    }

    private static func brute(step: Bool) -> [String] {
        [
            "....sssss....",
            "...swwwwws...",
            "..sSSSSSSSs..",
            "..SXXXXXXXS..",
            "..SSSSSSSSS..",
            ".nSrRRRRRrSn.",
            "nSSrRRRRRrSSn",
            "nSSrrRRRrrSSn",
            ".nSSSSSSSSSn.",
            step ? "...nnn.nnn..." : "..nnn...nnn..",
            step ? "...DDD.DDD..." : "..DDD...DDD..",
        ]
    }

    private static func medic(feet: String) -> [String] {
        [
            "...yyyyy...",
            "...........",
            "...GGGGG...",
            "..GKGGGKG..",
            ".GGGGGGGGG.",
            ".GGGGWGGGG.",
            ".gGGWWWGGg.",
            ".gGGGWGGGg.",
            "..ggggggg..",
            feet,
        ]
    }

    private static let wispUp = [
        "P...........P",
        "PP...fff...PP",
        "PPP.fffff.PPP",
        ".PPPfWfWfPPP.",
        "..PPfffffPP..",
        "....fffff....",
        ".....fff.....",
        "......f......",
    ]

    private static let wispDown = [
        ".....fff.....",
        "....fffff....",
        "....fWfWf....",
        "..PPfffffPP..",
        ".PPPfffffPPP.",
        "PPP..fff..PPP",
        "PP....f....PP",
        "P...........P",
    ]

    private static func splitter(feet: String) -> [String] {
        [
            "..C.....C..",
            "..CC...CC..",
            "...CbbbC...",
            "..bBBBBBb..",
            ".bBKBBBKBb.",
            ".bBBBBBBBb.",
            ".bBBWWWBBb.",
            "..bBBBBBb..",
            "...bbbbb...",
            feet,
        ]
    }

    private static func shard(legs: String) -> [String] {
        [
            "...C...",
            "..CWC..",
            ".CBBBC.",
            "CBKBKBC",
            ".bBBBb.",
            legs,
        ]
    }

    private static func titan(step: Bool) -> [String] {
        [
            "....y..y..y..y....",
            "....yYYyYYyYYy....",
            "...rRRRRRRRRRRr...",
            "..rRRRRRRRRRRRRr..",
            "..rRWWRRRRRRWWRr..",
            "..rRWKRRRRRRKWRr..",
            "..rRRRRRRRRRRRRr..",
            "..rRRXXXXXXXXRRr..",
            "..rrRRRRRRRRRRrr..",
            ".SSrrrrrrrrrrrrSS.",
            "SssSrRRRRRRRRrSssS",
            "SssSrRRYYYYRRrSssS",
            "SSSSrRRYyyYRRrSSSS",
            ".SS.rRRRYYRRRr.SS.",
            "....rrrrrrrrrr....",
            step ? ".....nnn..nnn....." : "....nnn....nnn....",
            step ? "....nnnn..nnnn...." : "...nnnn....nnnn...",
        ]
    }

    // MARK: Core and decoration

    static let coreCrystal = [
        "....W....",
        "...CWC...",
        "..CCWBC..",
        ".CCWWBBC.",
        ".CWWCBBb.",
        "CCWCCBBbb",
        ".CCCBBbb.",
        ".CCBBBbb.",
        "..CBBbb..",
        "...Bbb...",
        "....b....",
    ]

    static let corePedestal = [
        ".sssssssssss.",
        "swwwwwwwwwwws",
        "sSSSSSSSSSSSs",
        "SnSnSnSnSnSnS",
        "SSSSSSSSSSSSS",
        ".nnnnnnnnnnn.",
    ]

    static let rock = [
        "....sss.....",
        "..sswwsSS...",
        ".swwsSSSSn..",
        ".sSSSSSnSSn.",
        "SSSSSnSSSSnn",
        "SSnSSSSSSnnn",
        ".nnSSSSnnnn.",
        "..nnnnnnnn..",
    ]

    static let tree = [
        "....GGGG....",
        "..GGGGgGGG..",
        ".GGgGGGGgGg.",
        ".GGGGgGGGgg.",
        "GgGGGGGgGggh",
        "GGGgGGgGgghh",
        ".gGGgggGghh.",
        ".hgghgghhhh.",
        "..hhhhhhhh..",
        ".....DD.....",
        ".....Dd.....",
        "....DDdD....",
    ]

    /// Path direction marker (points up).
    static let chevron = [
        "..W..",
        ".W.W.",
        "W...W",
    ]

    /// Corner brackets that mark buildable tiles.
    static let bracket = [
        "WWW..........WWW",
        "W..............W",
        "W..............W",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "W..............W",
        "W..............W",
        "WWW..........WWW",
    ]

    static let healPlus = [
        ".G.",
        "GWG",
        ".G.",
    ]

    // MARK: UI icons

    enum Icon: String, CaseIterable {
        case heart, coin, skull, pause, play, fastForward, close, check, star, speaker, speakerOff, upgrade, target, question
        case flask, lock, bolt, medal
    }

    static func icon(_ icon: Icon) -> [String] {
        switch icon {
        case .heart:
            [".RR...RR.", "RWRR.RRRR", "RWRRRRRRR", "RRRRRRRRr", ".RRRRRRr.", "..RRRRr..", "...RRr...", "....r...."]
        case .coin:
            ["..YYYY..", ".YyyyYY.", "YyyYYYYo", "YyYYYYYo", "YyYYYYYo", "YYYYYYoo", ".YYYYoo.", "..oooo.."]
        case .skull:
            ["..wwwww..", ".wwwwwww.", "wwwwwwwww", "wKKwwwKKw", "wKKwwwKKw", "wwwwKwwww", ".wwwwwww.", "..wKwKw..", "..wwwww.."]
        case .pause:
            ["WW..WW", "WW..WW", "WW..WW", "WW..WW", "WW..WW", "WW..WW", "WW..WW"]
        case .play:
            ["W.....", "WW....", "WWW...", "WWWW..", "WWW...", "WW....", "W....."]
        case .fastForward:
            ["W...W...", "WW..WW..", "WWW.WWW.", "WWWWWWWW", "WWW.WWW.", "WW..WW..", "W...W..."]
        case .close:
            ["WW...WW", "WWW.WWW", ".WWWWW.", "..WWW..", ".WWWWW.", "WWW.WWW", "WW...WW"]
        case .check:
            ["......WW", ".....WWW", "W...WWW.", "WW.WWW..", "WWWWW...", ".WWW....", "..W....."]
        case .star:
            ["....Y....", "...YYY...", "YYYYyYYYY", ".YYyyyYY.", "..YYYYY..", ".YYYYYYY.", ".YYY.YYY.", "YY.....YY"]
        case .speaker:
            ["...W.....", "..WW..W..", "WWWW...W.", "WWWW.W.W.", "WWWW.W.W.", "WWWW...W.", "..WW..W..", "...W....."]
        case .speakerOff:
            ["...W.....", "..WW.....", "WWWW.W.W.", "WWWW..W..", "WWWW.W.W.", "WWWW.....", "..WW.....", "...W....."]
        case .upgrade:
            ["...W...", "..WWW..", ".WWWWW.", "WWWWWWW", "..WWW..", "..WWW..", "..WWW..", "..WWW.."]
        case .target:
            ["....W....", "..WWWWW..", ".W..W..W.", ".W.....W.", "WWW.W.WWW", ".W.....W.", ".W..W..W.", "..WWWWW..", "....W...."]
        case .question:
            [".WWW.", "W...W", "....W", "...W.", "..W..", ".....", "..W.."]
        case .flask:
            ["..sss..", "...s...", "...s...", "..sCs..", ".sCCCs.", "sCCGCCs", "sCGCCCs", "sCCCCCs", ".sssss."]
        case .lock:
            ["..sss..", ".s...s.", ".s...s.", "YYYYYYY", "YYYKYYY", "YYYKYYY", "ooooooo"]
        case .bolt:
            ["...YY", "..YY.", ".YY..", "YYYYY", "..YY.", ".YY..", "YY...", "Y...."]
        case .medal:
            ["RRR...BBB", ".RRR.BBB.", "..RR.BB..", "...YYY...", "..YyyyY..", ".YyYYYYo.", ".YyYYYYo.", ".YYYYYoo.", "..YYooo..", "...ooo..."]
        }
    }
}
