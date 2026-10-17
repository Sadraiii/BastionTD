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
        case .ironclad: [ironclad(step: false), ironclad(step: true)]
        case .pyrefiend: [pyrefiend(step: false), pyrefiend(step: true)]
        case .frostborn: [frostborn(step: false), frostborn(step: true)]
        case .voidling: [voidling(sway: false), voidling(sway: true)]
        case .blastguard: [blastguard(step: false), blastguard(step: true)]
        case .husk: [husk(step: false), husk(step: true)]
        case .mirage: [mirageUp, mirageDown]
        case .gargoyle: [gargoyleUp, gargoyleDown]
        case .warper: [warper(flicker: false), warper(flicker: true)]
        case .titan: [titan(step: false), titan(step: true)]
        case .dreadnought: [dreadnought(spin: false), dreadnought(spin: true)]
        case .overlord: [overlord(step: false), overlord(step: true)]
        }
    }

    private static func ironclad(step: Bool) -> [String] {
        [
            "...sssss...",
            "..swwwwws..",
            ".sSSSSSSSs.",
            ".sSKKKKKSs.",
            ".sSSSSSSSs.",
            "..sSSSSSs..",
            ".nsSSSSSsn.",
            "nnsSSnSSsnn",
            "nnsSSnSSsnn",
            "..sSSSSSs..",
            step ? ".nn.....nn." : "..nn...nn..",
            step ? ".NN.....NN." : "..NN...NN..",
        ]
    }

    private static func pyrefiend(step: Bool) -> [String] {
        [
            "...y...y...",
            "..yOy.yOy..",
            "..OOOyOOO..",
            ".OOOOOOOOO.",
            ".OOyyOyyOO.",
            ".ROOOOOOOR.",
            "RROOrrrOORR",
            ".RRROOORRR.",
            "..RRRRRRR..",
            "...RRRRR...",
            step ? "...o...o..." : "..o.....o..",
            step ? "..oo...oo.." : ".oo.....oo.",
        ]
    }

    private static func frostborn(step: Bool) -> [String] {
        [
            "....CCCC....",
            "...CwwwwC...",
            "..CwBwwBwC..",
            "..CwwwwwwC..",
            ".CCCwwwwCCC.",
            "CwwCCBBCCwwC",
            "CwwCBBBBCwwC",
            "CwwCCBBCCwwC",
            ".CC.CCCC.CC.",
            "....CbbC....",
            step ? "....CC.CC..." : "...CC..CC...",
            step ? "....bb.bb..." : "...bb..bb...",
        ]
    }

    private static func voidling(sway: Bool) -> [String] {
        [
            "..pppppp..",
            ".pKKKKKKp.",
            "pKKPKKPKKp",
            "pKKKKKKKKp",
            "pKKKffKKKp",
            ".pKKKKKKp.",
            "..pKKKKp..",
            sway ? "p..pKKp..p" : ".p.pKKp.p.",
            sway ? ".p..pp..p." : "p...pp...p",
        ]
    }

    private static func blastguard(step: Bool) -> [String] {
        [
            "....DDDD....",
            "...DddddD...",
            "..DdCCCCdD..",
            "..DdCCCCdD..",
            "..DddddddD..",
            ".DhhhhhhhhD.",
            "DhhhYhhYhhhD",
            "DhhhhhhhhhhD",
            ".DhhhhhhhhD.",
            "..Dhh..hhD..",
            step ? "...DD..DD..." : "..DD....DD..",
            step ? "..DDD..DDD.." : ".DDD....DDD.",
        ]
    }

    private static func husk(step: Bool) -> [String] {
        [
            "...gggg...",
            "..gGGGGg..",
            "..GKGGKG..",
            "..GGGGGG..",
            "..GGrrGG..",
            "...GGGG...",
            ".nnnnnnnn.",
            "GGnnnnnnGG",
            "G.nnnnnn.G",
            "..nnnnnn..",
            step ? "...DD.DD.." : "..DD..DD..",
            step ? "..DD..DD.." : ".DD....DD.",
        ]
    }

    private static let mirageUp = [
        "w...........w",
        "ww..wwwww..ww",
        "www.wCwCw.www",
        ".wwwwwwwwwww.",
        "..wwswwwsww..",
        "....wwwww....",
        ".....www.....",
        "......w......",
    ]

    private static let mirageDown = [
        "....wwwww....",
        "....wCwCw....",
        "..wwwwwwwww..",
        ".wwwwswswwww.",
        "www.wwwww.www",
        "ww...www...ww",
        "w.....w.....w",
    ]

    private static let gargoyleUp = [
        "s...........s",
        "ss..nnnnn..ss",
        "sss.nRnRn.sss",
        "ssssnnnnnssss",
        ".sssSnnnSsss.",
        "..ssSSSSSss..",
        "....SSSSS....",
        "....SnSnS....",
        "....n...n....",
    ]

    private static let gargoyleDown = [
        "....nnnnn....",
        "....nRnRn....",
        "ssssnnnnnssss",
        "sssSSnnnSSsss",
        "ss.SSSSSSS.ss",
        "s...SSSSS...s",
        "....SnSnS....",
        "....n...n....",
    ]

    private static func warper(flicker: Bool) -> [String] {
        [
            "...BBBB...",
            "..BCCCCB..",
            ".BCWCCWCB.",
            ".BCCCCCCB.",
            "..BCPPCB..",
            ".pBBPPBBp.",
            "p.pBBBBp.p",
            "..pBBBBp..",
            "...pBBp...",
            flicker ? "....pp...." : "...p..p...",
            flicker ? "...p..p..." : "..p....p..",
        ]
    }

    private static func dreadnought(spin: Bool) -> [String] {
        [
            "......nnnnnnnnnn......",
            "....nnSSSSSSSSSSnn....",
            "..nnSSssssssssssSSnn..",
            ".nSSssSSSSSSSSSSssSSn.",
            "nSSSRRRRRRRRRRRRRRSSSn",
            "nSSKSSKSSKSSKSSKSSKSSn",
            "nSSSSSSSSSSSSSSSSSSSSn",
            ".nSSRRRRRRRRRRRRRRSSn.",
            "..nnSSSSSSSSSSSSSSnn..",
            "....nnnnSSSSSSnnnn....",
            "........nnYYnn........",
            spin ? "......s...YY...s......" : ".......s..YY..s.......",
            spin ? ".......s..OO..s......." : "......sss.OO.sss......",
            spin ? "..........OO.........." : "...........O..........",
        ]
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

    // MARK: Commanders (two walking frames each)

    static func commanderFrames(_ kind: CommanderKind) -> [[String]] {
        switch kind {
        case .knight: [knight(legs: "...nn.nn...."), knight(legs: "..nn...nn...")]
        case .mage: [mage(feet: "..uu...uu..."), mage(feet: "...uu.uu....")]
        case .ranger: [ranger(legs: "...DD.DD...."), ranger(legs: "..DD...DD...")]
        case .engineer: [engineer(legs: "...nn.nn...."), engineer(legs: "..nn...nn...")]
        case .healer: [healer(feet: "..uu...uu..."), healer(feet: "...uu.uu....")]
        }
    }

    private static func knight(legs: String) -> [String] {
        [
            ".....RR.....",
            "....RRs.....",
            "...swwws....",
            "...wKwKw....",
            "...swwws....",
            "....sss.....",
            "..BsSSSsY...",
            ".BBsSwSsY...",
            ".BBsSSSsY...",
            ".BB.sSs.Y...",
            "....sSs.....",
            legs,
        ]
    }

    private static func mage(feet: String) -> [String] {
        [
            ".....p......",
            "....ppp.....",
            "...ppppp....",
            "..ppppppp.C.",
            "....eee..CW.",
            "....eKe..s..",
            "...PpppP.s..",
            "..PPpppPPs..",
            "...PpppP.s..",
            "...ppppp.s..",
            "..ppppppp...",
            feet,
        ]
    }

    private static func engineer(legs: String) -> [String] {
        [
            "....yyyy....",
            "...yYYYYy...",
            "..yYYYYYYy..",
            "...eeeee....",
            "...eKeKe....",
            "...eeeee....",
            "..OOOOOOO.s.",
            ".eOyOOOyOss.",
            ".eOOOOOOO.s.",
            "..OOOOOOO.s.",
            "...bbbbb....",
            legs,
        ]
    }

    private static func healer(feet: String) -> [String] {
        [
            "....WWW.....",
            "...WWWWW....",
            "...weeew....",
            "...eKeKe....",
            "...weeew....",
            "..WWWGWWW...",
            ".eWWGGGWWe..",
            ".eWWWGWWWe..",
            "..WWWWWWW...",
            "..WWWWWWW...",
            "..wwwwwww...",
            feet,
        ]
    }

    private static func ranger(legs: String) -> [String] {
        [
            "....hhh.....",
            "...hgggh....",
            "...geeeg..D.",
            "...eKeKe.D..",
            "...geeeg.Dw.",
            "..hgGGGghDw.",
            "..eGGGGG.Dw.",
            "..eGGGGG.D..",
            "...GGGG...D.",
            "...gg.gg....",
            "...gg.gg....",
            legs,
        ]
    }

    /// Decoration sprites for a terrain; obstacles pick one by their cell.
    static func props(_ terrain: Terrain) -> [[String]] {
        switch terrain {
        case .grassland: [tree, rock]
        case .desert: [cactus, spire]
        case .snowfield: [pine, iceRock]
        case .volcanic: [deadTree(bark: "N", light: "n"), obsidian]
        case .swamp: [deadTree(bark: "D", light: "d"), mossRock]
        }
    }

    static let cactus = [
        "....f.......",
        "....gg......",
        "...gGGg.....",
        "...gGgg.....",
        ".g.gGgg.....",
        "gGggGgg.g...",
        "gGggGgg.gG..",
        ".ggggGggGg..",
        "...gGgggg...",
        "...gGgg.....",
        "...gGgg.....",
        "..dgGggd....",
    ]

    static let spire = [
        "....LL......",
        "...LeeL.....",
        "...LeLLd....",
        "..LeeLLdd...",
        "..LeLLLLd...",
        ".LeeLLLLdd..",
        ".LLLLLLddd..",
        "..dddddddd..",
    ]

    static let pine = [
        ".....WW.....",
        "....WWhh....",
        "...WWWhhh...",
        "....WhhH....",
        "...WWWhhH...",
        "..WWWhhhHH..",
        "...WhhhhH...",
        "..WWhhhhHH..",
        ".WWWhhhhhHH.",
        "..hhhhhhHH..",
        ".....Dd.....",
        "....DDdD....",
    ]

    static let iceRock = [
        "....WWW.....",
        "..WWCCwSS...",
        ".WCCCwwSSn..",
        ".wCCwwwSSn..",
        "CCwwwwSSSnn.",
        "CwwwwSSSnnnn",
        ".SSSSSSnnnn.",
        "..nnnnnnnn..",
    ]

    static let obsidian = [
        "....nnn.....",
        "..nnSnNNN...",
        ".nSnNNNNNK..",
        ".nNNNONNNK..",
        "NNNNOYONNKK.",
        "NNNNNONNNKKK",
        ".NNNNNNKKKK.",
        "..KKKKKKKK..",
    ]

    static let mossRock = [
        "....ggg.....",
        "..ggGgsSS...",
        ".sgGgsSSSn..",
        ".sSSgSSnSSn.",
        "SSSSSnSSgSnn",
        "SSnSSSSSSnnn",
        ".nnSSSSnnnn.",
        "..nnnnnnnn..",
    ]

    /// A bare tree; `bark` and `light` pick its colors (charred or wet wood).
    static func deadTree(bark: Character, light: Character) -> [String] {
        [
            "..D.....D...",
            "..DD...DD...",
            "...DD.DD..D.",
            "D...DDD..DD.",
            "DD...DD.DD..",
            ".DD..DDDD...",
            "..DDDDDD....",
            ".....DD.....",
            ".....DD.....",
            ".....Dd.....",
            ".....Dd.....",
            "....DDdD....",
        ].map { String($0.map { $0 == "D" ? bark : $0 == "d" ? light : $0 }) }
    }

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
