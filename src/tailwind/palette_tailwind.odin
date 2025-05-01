package tailwind
import rl "vendor:raylib"
import "core:math/rand"

COLOR :: enum {
    // {{{
    SLATE0,   SLATE1,   SLATE2,   SLATE3,   SLATE4,   SLATE5,   SLATE6,   SLATE7,   SLATE8,    SLATE9,
    GRAY0,    GRAY1,    GRAY2,    GRAY3,    GRAY4,    GRAY5,    GRAY6,    GRAY7,    GRAY8,     GRAY9,
    ZINC0,    ZINC1,    ZINC2,    ZINC3,    ZINC4,    ZINC5,    ZINC6,    ZINC7,    ZINC8,     ZINC9,
    NEUTRAL0, NEUTRAL1, NEUTRAL2, NEUTRAL3, NEUTRAL4, NEUTRAL5, NEUTRAL6, NEUTRAL7, NEUTRAL8,  NEUTRAL9,
    STONE0,   STONE1,   STONE2,   STONE3,   STONE4,   STONE5,   STONE6,   STONE7,   STONE8,    STONE9,
    RED0,     RED1,     RED2,     RED3,     RED4,     RED5,     RED6,     RED7,     RED8,      RED9,
    ORANGE0,  ORANGE1,  ORANGE2,  ORANGE3,  ORANGE4,  ORANGE5,  ORANGE6,  ORANGE7,  ORANGE8,   ORANGE9,
    AMBER0,   AMBER1,   AMBER2,   AMBER3,   AMBER4,   AMBER5,   AMBER6,   AMBER7,   AMBER8,    AMBER9,
    YELLOW0,  YELLOW1,  YELLOW2,  YELLOW3,  YELLOW4,  YELLOW5,  YELLOW6,  YELLOW7,  YELLOW8,   YELLOW9,
    LIME0,    LIME1,    LIME2,    LIME3,    LIME4,    LIME5,    LIME6,    LIME7,    LIME8,     LIME9,
    GREEN0,   GREEN1,   GREEN2,   GREEN3,   GREEN4,   GREEN5,   GREEN6,   GREEN7,   GREEN8,    GREEN9,
    EMERALD0, EMERALD1, EMERALD2, EMERALD3, EMERALD4, EMERALD5, EMERALD6, EMERALD7, EMERALD8,  EMERALD9,
    TEAL0,    TEAL1,    TEAL2,    TEAL3,    TEAL4,    TEAL5,    TEAL6,    TEAL7,    TEAL8,     TEAL9,
    CYAN0,    CYAN1,    CYAN2,    CYAN3,    CYAN4,    CYAN5,    CYAN6,    CYAN7,    CYAN8,     CYAN9,
    SKY0,     SKY1,     SKY2,     SKY3,     SKY4,     SKY5,     SKY6,     SKY7,     SKY8,      SKY9,
    BLUE0,    BLUE1,    BLUE2,    BLUE3,    BLUE4,    BLUE5,    BLUE6,    BLUE7,    BLUE8,     BLUE9,
    INDIGO0,  INDIGO1,  INDIGO2,  INDIGO3,  INDIGO4,  INDIGO5,  INDIGO6,  INDIGO7,  INDIGO8,   INDIGO9,
    VIOLET0,  VIOLET1,  VIOLET2,  VIOLET3,  VIOLET4,  VIOLET5,  VIOLET6,  VIOLET7,  VIOLET8,   VIOLET9,
    PURPLE0,  PURPLE1,  PURPLE2,  PURPLE3,  PURPLE4,  PURPLE5,  PURPLE6,  PURPLE7,  PURPLE8,   PURPLE9,
    FUCHSIA0, FUCHSIA1, FUCHSIA2, FUCHSIA3, FUCHSIA4, FUCHSIA5, FUCHSIA6, FUCHSIA7, FUCHSIA8,  FUCHSIA9,
    PINK0,    PINK1,    PINK2,    PINK3,    PINK4,    PINK5,    PINK6,    PINK7,    PINK8,     PINK9,
    ROSE0,    ROSE1,    ROSE2,    ROSE3,    ROSE4,    ROSE5,    ROSE6,    ROSE7,    ROSE8,     ROSE9,
    // }}}
}

COLORS : [COLOR]rl.Color : {
    // {{{
    .SLATE0   = {0xF1, 0xF5, 0xF9, 0xFF}, // #F1F5F9
    .SLATE1   = {0xE2, 0xE8, 0xF0, 0xFF}, // #E2E8F0
    .SLATE2   = {0xCB, 0xD5, 0xE1, 0xFF}, // #CBD5E1
    .SLATE3   = {0x94, 0xA3, 0xB8, 0xFF}, // #94A3B8
    .SLATE4   = {0x64, 0x74, 0x8B, 0xFF}, // #64748B
    .SLATE5   = {0x47, 0x55, 0x69, 0xFF}, // #475569
    .SLATE6   = {0x33, 0x41, 0x55, 0xFF}, // #334155
    .SLATE7   = {0x1E, 0x29, 0x3B, 0xFF}, // #1E293B
    .SLATE8   = {0x0F, 0x17, 0x2A, 0xFF}, // #0F172A
    .SLATE9   = {0x02, 0x06, 0x17, 0xFF}, // #020617

    .GRAY0    = {0xF3, 0xF4, 0xF6, 0xFF}, // #F3F4F6
    .GRAY1    = {0xE5, 0xE7, 0xEB, 0xFF}, // #E5E7EB
    .GRAY2    = {0xD1, 0xD5, 0xDB, 0xFF}, // #D1D5DB
    .GRAY3    = {0x9C, 0xA3, 0xAF, 0xFF}, // #9CA3AF
    .GRAY4    = {0x6B, 0x72, 0x80, 0xFF}, // #6B7280
    .GRAY5    = {0x4B, 0x55, 0x63, 0xFF}, // #4B5563
    .GRAY6    = {0x37, 0x41, 0x51, 0xFF}, // #374151
    .GRAY7    = {0x1F, 0x29, 0x37, 0xFF}, // #1F2937
    .GRAY8    = {0x11, 0x18, 0x27, 0xFF}, // #111827
    .GRAY9    = {0x03, 0x07, 0x12, 0xFF}, // #030712

    .ZINC0    = {0xF4, 0xF4, 0xF5, 0xFF}, // #F4F4F5
    .ZINC1    = {0xE4, 0xE4, 0xE7, 0xFF}, // #E4E4E7
    .ZINC2    = {0xD4, 0xD4, 0xD8, 0xFF}, // #D4D4D8
    .ZINC3    = {0xA1, 0xA1, 0xAA, 0xFF}, // #A1A1AA
    .ZINC4    = {0x71, 0x71, 0x7A, 0xFF}, // #71717A
    .ZINC5    = {0x52, 0x52, 0x5B, 0xFF}, // #52525B
    .ZINC6    = {0x3F, 0x3F, 0x46, 0xFF}, // #3F3F46
    .ZINC7    = {0x27, 0x27, 0x2A, 0xFF}, // #27272A
    .ZINC8    = {0x18, 0x18, 0x1B, 0xFF}, // #18181B
    .ZINC9    = {0x09, 0x09, 0x0B, 0xFF}, // #09090B

    .NEUTRAL0 = {0xF5, 0xF5, 0xF5, 0xFF}, // #F5F5F5
    .NEUTRAL1 = {0xE5, 0xE5, 0xE5, 0xFF}, // #E5E5E5
    .NEUTRAL2 = {0xD4, 0xD4, 0xD4, 0xFF}, // #D4D4D4
    .NEUTRAL3 = {0xA3, 0xA3, 0xA3, 0xFF}, // #A3A3A3
    .NEUTRAL4 = {0x73, 0x73, 0x73, 0xFF}, // #737373
    .NEUTRAL5 = {0x52, 0x52, 0x52, 0xFF}, // #525252
    .NEUTRAL6 = {0x40, 0x40, 0x40, 0xFF}, // #404040
    .NEUTRAL7 = {0x26, 0x26, 0x26, 0xFF}, // #262626
    .NEUTRAL8 = {0x17, 0x17, 0x17, 0xFF}, // #171717
    .NEUTRAL9 = {0x0A, 0x0A, 0x0A, 0xFF}, // #0A0A0A

    .STONE0   = {0xF5, 0xF5, 0xF4, 0xFF}, // #F5F5F4
    .STONE1   = {0xE7, 0xE5, 0xE4, 0xFF}, // #E7E5E4
    .STONE2   = {0xD6, 0xD3, 0xD1, 0xFF}, // #D6D3D1
    .STONE3   = {0xA8, 0xA2, 0x9E, 0xFF}, // #A8A29E
    .STONE4   = {0x78, 0x71, 0x6C, 0xFF}, // #78716C
    .STONE5   = {0x57, 0x53, 0x4E, 0xFF}, // #57534E
    .STONE6   = {0x44, 0x40, 0x3C, 0xFF}, // #44403C
    .STONE7   = {0x29, 0x25, 0x24, 0xFF}, // #292524
    .STONE8   = {0x1C, 0x19, 0x17, 0xFF}, // #1C1917
    .STONE9   = {0x0C, 0x0A, 0x09, 0xFF}, // #0C0A09

    .RED0     = {0xFE, 0xE2, 0xE2, 0xFF}, // #FEE2E2
    .RED1     = {0xFE, 0xCA, 0xCA, 0xFF}, // #FECACA
    .RED2     = {0xFC, 0xA5, 0xA5, 0xFF}, // #FCA5A5
    .RED3     = {0xF8, 0x71, 0x71, 0xFF}, // #F87171
    .RED4     = {0xEF, 0x44, 0x44, 0xFF}, // #EF4444
    .RED5     = {0xDC, 0x26, 0x26, 0xFF}, // #DC2626
    .RED6     = {0xB9, 0x1C, 0x1C, 0xFF}, // #B91C1C
    .RED7     = {0x99, 0x1B, 0x1B, 0xFF}, // #991B1B
    .RED8     = {0x7F, 0x1D, 0x1D, 0xFF}, // #7F1D1D
    .RED9     = {0x45, 0x0A, 0x0A, 0xFF}, // #450A0A

    .ORANGE0  = {0xFF, 0xED, 0xD5, 0xFF}, // #FFEDD5
    .ORANGE1  = {0xFE, 0xD7, 0xAA, 0xFF}, // #FED7AA
    .ORANGE2  = {0xFD, 0xBA, 0x74, 0xFF}, // #FDBA74
    .ORANGE3  = {0xFB, 0x92, 0x3C, 0xFF}, // #FB923C
    .ORANGE4  = {0xF9, 0x73, 0x16, 0xFF}, // #F97316
    .ORANGE5  = {0xEA, 0x58, 0x0C, 0xFF}, // #EA580C
    .ORANGE6  = {0xC2, 0x41, 0x0C, 0xFF}, // #C2410C
    .ORANGE7  = {0x9A, 0x34, 0x12, 0xFF}, // #9A3412
    .ORANGE8  = {0x7C, 0x2D, 0x12, 0xFF}, // #7C2D12
    .ORANGE9  = {0x43, 0x14, 0x07, 0xFF}, // #431407

    .AMBER0   = {0xFE, 0xF3, 0xC7, 0xFF}, // #FEF3C7
    .AMBER1   = {0xFD, 0xE6, 0x8A, 0xFF}, // #FDE68A
    .AMBER2   = {0xFC, 0xD3, 0x4D, 0xFF}, // #FCD34D
    .AMBER3   = {0xFB, 0xBF, 0x24, 0xFF}, // #FBBF24
    .AMBER4   = {0xF5, 0x9E, 0x0B, 0xFF}, // #F59E0B
    .AMBER5   = {0xD9, 0x77, 0x06, 0xFF}, // #D97706
    .AMBER6   = {0xB4, 0x53, 0x09, 0xFF}, // #B45309
    .AMBER7   = {0x92, 0x40, 0x0E, 0xFF}, // #92400E
    .AMBER8   = {0x78, 0x35, 0x0F, 0xFF}, // #78350F
    .AMBER9   = {0x45, 0x1A, 0x03, 0xFF}, // #451A03

    .YELLOW0  = {0xFE, 0xF9, 0xC3, 0xFF}, // #FEF9C3
    .YELLOW1  = {0xFE, 0xF0, 0x8A, 0xFF}, // #FEF08A
    .YELLOW2  = {0xFD, 0xE0, 0x47, 0xFF}, // #FDE047
    .YELLOW3  = {0xFA, 0xCC, 0x15, 0xFF}, // #FACC15
    .YELLOW4  = {0xEA, 0xB3, 0x08, 0xFF}, // #EAB308
    .YELLOW5  = {0xCA, 0x8A, 0x04, 0xFF}, // #CA8A04
    .YELLOW6  = {0xA1, 0x62, 0x07, 0xFF}, // #A16207
    .YELLOW7  = {0x85, 0x4D, 0x0E, 0xFF}, // #854D0E
    .YELLOW8  = {0x71, 0x3F, 0x12, 0xFF}, // #713F12
    .YELLOW9  = {0x42, 0x20, 0x06, 0xFF}, // #422006

    .LIME0    = {0xEC, 0xFC, 0xCB, 0xFF}, // #ECFCCB
    .LIME1    = {0xD9, 0xF9, 0x9D, 0xFF}, // #D9F99D
    .LIME2    = {0xBE, 0xF2, 0x64, 0xFF}, // #BEF264
    .LIME3    = {0xA3, 0xE6, 0x35, 0xFF}, // #A3E635
    .LIME4    = {0x84, 0xCC, 0x16, 0xFF}, // #84CC16
    .LIME5    = {0x65, 0xA3, 0x0D, 0xFF}, // #65A30D
    .LIME6    = {0x4D, 0x7C, 0x0F, 0xFF}, // #4D7C0F
    .LIME7    = {0x3F, 0x62, 0x12, 0xFF}, // #3F6212
    .LIME8    = {0x36, 0x53, 0x14, 0xFF}, // #365314
    .LIME9    = {0x1A, 0x2E, 0x05, 0xFF}, // #1A2E05

    .GREEN0   = {0xDC, 0xFC, 0xE7, 0xFF}, // #DCFCE7
    .GREEN1   = {0xBB, 0xF7, 0xD0, 0xFF}, // #BBF7D0
    .GREEN2   = {0x86, 0xEF, 0xAC, 0xFF}, // #86EFAC
    .GREEN3   = {0x4A, 0xDE, 0x80, 0xFF}, // #4ADE80
    .GREEN4   = {0x22, 0xC5, 0x5E, 0xFF}, // #22C55E
    .GREEN5   = {0x16, 0xA3, 0x4A, 0xFF}, // #16A34A
    .GREEN6   = {0x15, 0x80, 0x3D, 0xFF}, // #15803D
    .GREEN7   = {0x16, 0x65, 0x34, 0xFF}, // #166534
    .GREEN8   = {0x14, 0x53, 0x2D, 0xFF}, // #14532D
    .GREEN9   = {0x05, 0x2E, 0x16, 0xFF}, // #052E16

    .EMERALD0 = {0xD1, 0xFA, 0xE5, 0xFF}, // #D1FAE5
    .EMERALD1 = {0xA7, 0xF3, 0xD0, 0xFF}, // #A7F3D0
    .EMERALD2 = {0x6E, 0xE7, 0xB7, 0xFF}, // #6EE7B7
    .EMERALD3 = {0x34, 0xD3, 0x99, 0xFF}, // #34D399
    .EMERALD4 = {0x10, 0xB9, 0x81, 0xFF}, // #10B981
    .EMERALD5 = {0x05, 0x96, 0x69, 0xFF}, // #059669
    .EMERALD6 = {0x04, 0x78, 0x57, 0xFF}, // #047857
    .EMERALD7 = {0x06, 0x5F, 0x46, 0xFF}, // #065F46
    .EMERALD8 = {0x06, 0x4E, 0x3B, 0xFF}, // #064E3B
    .EMERALD9 = {0x02, 0x2C, 0x22, 0xFF}, // #022C22

    .TEAL0    = {0xCC, 0xFB, 0xF1, 0xFF}, // #CCFBF1
    .TEAL1    = {0x99, 0xF6, 0xE4, 0xFF}, // #99F6E4
    .TEAL2    = {0x5E, 0xEA, 0xD4, 0xFF}, // #5EEAD4
    .TEAL3    = {0x2D, 0xD4, 0xBF, 0xFF}, // #2DD4BF
    .TEAL4    = {0x14, 0xB8, 0xA6, 0xFF}, // #14B8A6
    .TEAL5    = {0x0D, 0x94, 0x88, 0xFF}, // #0D9488
    .TEAL6    = {0x0F, 0x76, 0x6E, 0xFF}, // #0F766E
    .TEAL7    = {0x11, 0x5E, 0x59, 0xFF}, // #115E59
    .TEAL8    = {0x13, 0x4E, 0x4A, 0xFF}, // #134E4A
    .TEAL9    = {0x04, 0x2F, 0x2E, 0xFF}, // #042F2E

    .CYAN0    = {0xCF, 0xFA, 0xFE, 0xFF}, // #CFFAFE
    .CYAN1    = {0xA5, 0xF3, 0xFC, 0xFF}, // #A5F3FC
    .CYAN2    = {0x67, 0xE8, 0xF9, 0xFF}, // #67E8F9
    .CYAN3    = {0x22, 0xD3, 0xEE, 0xFF}, // #22D3EE
    .CYAN4    = {0x06, 0xB6, 0xD4, 0xFF}, // #06B6D4
    .CYAN5    = {0x08, 0x91, 0xB2, 0xFF}, // #0891B2
    .CYAN6    = {0x0E, 0x74, 0x90, 0xFF}, // #0E7490
    .CYAN7    = {0x15, 0x5E, 0x75, 0xFF}, // #155E75
    .CYAN8    = {0x16, 0x4E, 0x63, 0xFF}, // #164E63
    .CYAN9    = {0x08, 0x33, 0x44, 0xFF}, // #083344

    .SKY0     = {0xE0, 0xF2, 0xFE, 0xFF}, // #E0F2FE
    .SKY1     = {0xBA, 0xE6, 0xFD, 0xFF}, // #BAE6FD
    .SKY2     = {0x7D, 0xD3, 0xFC, 0xFF}, // #7DD3FC
    .SKY3     = {0x38, 0xBD, 0xF8, 0xFF}, // #38BDF8
    .SKY4     = {0x0E, 0xA5, 0xE9, 0xFF}, // #0EA5E9
    .SKY5     = {0x02, 0x84, 0xC7, 0xFF}, // #0284C7
    .SKY6     = {0x03, 0x69, 0xA1, 0xFF}, // #0369A1
    .SKY7     = {0x07, 0x59, 0x85, 0xFF}, // #075985
    .SKY8     = {0x0C, 0x4A, 0x6E, 0xFF}, // #0C4A6E
    .SKY9     = {0x08, 0x2F, 0x49, 0xFF}, // #082F49

    .BLUE0    = {0xDB, 0xEA, 0xFE, 0xFF}, // #DBEAFE
    .BLUE1    = {0xBF, 0xDB, 0xFE, 0xFF}, // #BFDBFE
    .BLUE2    = {0x93, 0xC5, 0xFD, 0xFF}, // #93C5FD
    .BLUE3    = {0x60, 0xA5, 0xFA, 0xFF}, // #60A5FA
    .BLUE4    = {0x3B, 0x82, 0xF6, 0xFF}, // #3B82F6
    .BLUE5    = {0x25, 0x63, 0xEB, 0xFF}, // #2563EB
    .BLUE6    = {0x1D, 0x4E, 0xD8, 0xFF}, // #1D4ED8
    .BLUE7    = {0x1E, 0x40, 0xAF, 0xFF}, // #1E40AF
    .BLUE8    = {0x1E, 0x3A, 0x8A, 0xFF}, // #1E3A8A
    .BLUE9    = {0x17, 0x25, 0x54, 0xFF}, // #172554

    .INDIGO0  = {0xE0, 0xE7, 0xFF, 0xFF}, // #E0E7FF
    .INDIGO1  = {0xC7, 0xD2, 0xFE, 0xFF}, // #C7D2FE
    .INDIGO2  = {0xA5, 0xB4, 0xFC, 0xFF}, // #A5B4FC
    .INDIGO3  = {0x81, 0x8C, 0xF8, 0xFF}, // #818CF8
    .INDIGO4  = {0x63, 0x66, 0xF1, 0xFF}, // #6366F1
    .INDIGO5  = {0x4F, 0x46, 0xE5, 0xFF}, // #4F46E5
    .INDIGO6  = {0x43, 0x38, 0xCA, 0xFF}, // #4338CA
    .INDIGO7  = {0x37, 0x30, 0xA3, 0xFF}, // #3730A3
    .INDIGO8  = {0x31, 0x2E, 0x81, 0xFF}, // #312E81
    .INDIGO9  = {0x1E, 0x1B, 0x4B, 0xFF}, // #1E1B4B

    .VIOLET0  = {0xED, 0xE9, 0xFE, 0xFF}, // #EDE9FE
    .VIOLET1  = {0xDD, 0xD6, 0xFE, 0xFF}, // #DDD6FE
    .VIOLET2  = {0xC4, 0xB5, 0xFD, 0xFF}, // #C4B5FD
    .VIOLET3  = {0xA7, 0x8B, 0xFA, 0xFF}, // #A78BFA
    .VIOLET4  = {0x8B, 0x5C, 0xF6, 0xFF}, // #8B5CF6
    .VIOLET5  = {0x7C, 0x3A, 0xED, 0xFF}, // #7C3AED
    .VIOLET6  = {0x6D, 0x28, 0xD9, 0xFF}, // #6D28D9
    .VIOLET7  = {0x5B, 0x21, 0xB6, 0xFF}, // #5B21B6
    .VIOLET8  = {0x4C, 0x1D, 0x95, 0xFF}, // #4C1D95
    .VIOLET9  = {0x2E, 0x10, 0x65, 0xFF}, // #2E1065

    .PURPLE0  = {0xF3, 0xE8, 0xFF, 0xFF}, // #F3E8FF
    .PURPLE1  = {0xE9, 0xD5, 0xFF, 0xFF}, // #E9D5FF
    .PURPLE2  = {0xD8, 0xB4, 0xFE, 0xFF}, // #D8B4FE
    .PURPLE3  = {0xC0, 0x84, 0xFC, 0xFF}, // #C084FC
    .PURPLE4  = {0xA8, 0x55, 0xF7, 0xFF}, // #A855F7
    .PURPLE5  = {0x93, 0x33, 0xEA, 0xFF}, // #9333EA
    .PURPLE6  = {0x7E, 0x22, 0xCE, 0xFF}, // #7E22CE
    .PURPLE7  = {0x6B, 0x21, 0xA8, 0xFF}, // #6B21A8
    .PURPLE8  = {0x58, 0x1C, 0x87, 0xFF}, // #581C87
    .PURPLE9  = {0x3B, 0x07, 0x64, 0xFF}, // #3B0764

    .FUCHSIA0 = {0xFA, 0xE8, 0xFF, 0xFF}, // #FAE8FF
    .FUCHSIA1 = {0xF5, 0xD0, 0xFE, 0xFF}, // #F5D0FE
    .FUCHSIA2 = {0xF0, 0xAB, 0xFC, 0xFF}, // #F0ABFC
    .FUCHSIA3 = {0xE8, 0x79, 0xF9, 0xFF}, // #E879F9
    .FUCHSIA4 = {0xD9, 0x46, 0xEF, 0xFF}, // #D946EF
    .FUCHSIA5 = {0xC0, 0x26, 0xD3, 0xFF}, // #C026D3
    .FUCHSIA6 = {0xA2, 0x1C, 0xAF, 0xFF}, // #A21CAF
    .FUCHSIA7 = {0x86, 0x19, 0x8F, 0xFF}, // #86198F
    .FUCHSIA8 = {0x70, 0x1A, 0x75, 0xFF}, // #701A75
    .FUCHSIA9 = {0x4A, 0x04, 0x4E, 0xFF}, // #4A044E

    .PINK0    = {0xFC, 0xE7, 0xF3, 0xFF}, // #FCE7F3
    .PINK1    = {0xFB, 0xCF, 0xE8, 0xFF}, // #FBCFE8
    .PINK2    = {0xF9, 0xA8, 0xD4, 0xFF}, // #F9A8D4
    .PINK3    = {0xF4, 0x72, 0xB6, 0xFF}, // #F472B6
    .PINK4    = {0xEC, 0x48, 0x99, 0xFF}, // #EC4899
    .PINK5    = {0xDB, 0x27, 0x77, 0xFF}, // #DB2777
    .PINK6    = {0xBE, 0x18, 0x5D, 0xFF}, // #BE185D
    .PINK7    = {0x9D, 0x17, 0x4D, 0xFF}, // #9D174D
    .PINK8    = {0x83, 0x18, 0x43, 0xFF}, // #831843
    .PINK9    = {0x50, 0x07, 0x24, 0xFF}, // #500724

    .ROSE0    = {0xFF, 0xE4, 0xE6, 0xFF}, // #FFE4E6
    .ROSE1    = {0xFE, 0xCD, 0xD3, 0xFF}, // #FECDD3
    .ROSE2    = {0xFD, 0xA4, 0xAF, 0xFF}, // #FDA4AF
    .ROSE3    = {0xFB, 0x71, 0x85, 0xFF}, // #FB7185
    .ROSE4    = {0xF4, 0x3F, 0x5E, 0xFF}, // #F43F5E
    .ROSE5    = {0xE1, 0x1D, 0x48, 0xFF}, // #E11D48
    .ROSE6    = {0xBE, 0x12, 0x3C, 0xFF}, // #BE123C
    .ROSE7    = {0x9F, 0x12, 0x39, 0xFF}, // #9F1239
    .ROSE8    = {0x88, 0x13, 0x37, 0xFF}, // #881337
    .ROSE9    = {0x4C, 0x05, 0x19, 0xFF}, // #4C0519
    // }}}
}

TW :: proc(color_code: COLOR) -> rl.Color {
    colors := COLORS
    return colors[color_code]
}

TW_RANDOM :: proc() -> rl.Color {
    colors := COLORS
    return colors[rand.choice_enum(COLOR)]
}

/* {{{

.SLATE0   = #F1F5F9
.SLATE1   = #E2E8F0
.SLATE2   = #CBD5E1
.SLATE3   = #94A3B8
.SLATE4   = #64748B
.SLATE5   = #475569
.SLATE6   = #334155
.SLATE7   = #1E293B
.SLATE8   = #0F172A
.SLATE9   = #020617

.GRAY0    = #F3F4F6
.GRAY1    = #E5E7EB
.GRAY2    = #D1D5DB
.GRAY3    = #9CA3AF
.GRAY4    = #6B7280
.GRAY5    = #4B5563
.GRAY6    = #374151
.GRAY7    = #1F2937
.GRAY8    = #111827
.GRAY9    = #030712

.ZINC0    = #F4F4F5
.ZINC1    = #E4E4E7
.ZINC2    = #D4D4D8
.ZINC3    = #A1A1AA
.ZINC4    = #71717A
.ZINC5    = #52525B
.ZINC6    = #3F3F46
.ZINC7    = #27272A
.ZINC8    = #18181B
.ZINC9    = #09090B

.NEUTRAL0 = #F5F5F5
.NEUTRAL1 = #E5E5E5
.NEUTRAL2 = #D4D4D4
.NEUTRAL3 = #A3A3A3
.NEUTRAL4 = #737373
.NEUTRAL5 = #525252
.NEUTRAL6 = #404040
.NEUTRAL7 = #262626
.NEUTRAL8 = #171717
.NEUTRAL9 = #0A0A0A

.STONE0   = #F5F5F4
.STONE1   = #E7E5E4
.STONE2   = #D6D3D1
.STONE3   = #A8A29E
.STONE4   = #78716C
.STONE5   = #57534E
.STONE6   = #44403C
.STONE7   = #292524
.STONE8   = #1C1917
.STONE9   = #0C0A09

.RED0     = #FEE2E2
.RED1     = #FECACA
.RED2     = #FCA5A5
.RED3     = #F87171
.RED4     = #EF4444
.RED5     = #DC2626
.RED6     = #B91C1C
.RED7     = #991B1B
.RED8     = #7F1D1D
.RED9     = #450A0A

.ORANGE0  = #FFEDD5
.ORANGE1  = #FED7AA
.ORANGE2  = #FDBA74
.ORANGE3  = #FB923C
.ORANGE4  = #F97316
.ORANGE5  = #EA580C
.ORANGE6  = #C2410C
.ORANGE7  = #9A3412
.ORANGE8  = #7C2D12
.ORANGE9  = #431407

.AMBER0   = #FEF3C7
.AMBER1   = #FDE68A
.AMBER2   = #FCD34D
.AMBER3   = #FBBF24
.AMBER4   = #F59E0B
.AMBER5   = #D97706
.AMBER6   = #B45309
.AMBER7   = #92400E
.AMBER8   = #78350F
.AMBER9   = #451A03

.YELLOW0  = #FEF9C3
.YELLOW1  = #FEF08A
.YELLOW2  = #FDE047
.YELLOW3  = #FACC15
.YELLOW4  = #EAB308
.YELLOW5  = #CA8A04
.YELLOW6  = #A16207
.YELLOW7  = #854D0E
.YELLOW8  = #713F12
.YELLOW9  = #422006

.LIME0    = #ECFCCB
.LIME1    = #D9F99D
.LIME2    = #BEF264
.LIME3    = #A3E635
.LIME4    = #84CC16
.LIME5    = #65A30D
.LIME6    = #4D7C0F
.LIME7    = #3F6212
.LIME8    = #365314
.LIME9    = #1A2E05

.GREEN0   = #DCFCE7
.GREEN1   = #BBF7D0
.GREEN2   = #86EFAC
.GREEN3   = #4ADE80
.GREEN4   = #22C55E
.GREEN5   = #16A34A
.GREEN6   = #15803D
.GREEN7   = #166534
.GREEN8   = #14532D
.GREEN9   = #052E16

.EMERALD0 = #D1FAE5
.EMERALD1 = #A7F3D0
.EMERALD2 = #6EE7B7
.EMERALD3 = #34D399
.EMERALD4 = #10B981
.EMERALD5 = #059669
.EMERALD6 = #047857
.EMERALD7 = #065F46
.EMERALD8 = #064E3B
.EMERALD9 = #022C22

.TEAL0    = #CCFBF1
.TEAL1    = #99F6E4
.TEAL2    = #5EEAD4
.TEAL3    = #2DD4BF
.TEAL4    = #14B8A6
.TEAL5    = #0D9488
.TEAL6    = #0F766E
.TEAL7    = #115E59
.TEAL8    = #134E4A
.TEAL9    = #042F2E

.CYAN0    = #CFFAFE
.CYAN1    = #A5F3FC
.CYAN2    = #67E8F9
.CYAN3    = #22D3EE
.CYAN4    = #06B6D4
.CYAN5    = #0891B2
.CYAN6    = #0E7490
.CYAN7    = #155E75
.CYAN8    = #164E63
.CYAN9    = #083344

.SKY0     = #E0F2FE
.SKY1     = #BAE6FD
.SKY2     = #7DD3FC
.SKY3     = #38BDF8
.SKY4     = #0EA5E9
.SKY5     = #0284C7
.SKY6     = #0369A1
.SKY7     = #075985
.SKY8     = #0C4A6E
.SKY9     = #082F49

.BLUE0    = #DBEAFE
.BLUE1    = #BFDBFE
.BLUE2    = #93C5FD
.BLUE3    = #60A5FA
.BLUE4    = #3B82F6
.BLUE5    = #2563EB
.BLUE6    = #1D4ED8
.BLUE7    = #1E40AF
.BLUE8    = #1E3A8A
.BLUE9    = #172554

.INDIGO0  = #E0E7FF
.INDIGO1  = #C7D2FE
.INDIGO2  = #A5B4FC
.INDIGO3  = #818CF8
.INDIGO4  = #6366F1
.INDIGO5  = #4F46E5
.INDIGO6  = #4338CA
.INDIGO7  = #3730A3
.INDIGO8  = #312E81
.INDIGO9  = #1E1B4B

.VIOLET0  = #EDE9FE
.VIOLET1  = #DDD6FE
.VIOLET2  = #C4B5FD
.VIOLET3  = #A78BFA
.VIOLET4  = #8B5CF6
.VIOLET5  = #7C3AED
.VIOLET6  = #6D28D9
.VIOLET7  = #5B21B6
.VIOLET8  = #4C1D95
.VIOLET9  = #2E1065

.PURPLE0  = #F3E8FF
.PURPLE1  = #E9D5FF
.PURPLE2  = #D8B4FE
.PURPLE3  = #C084FC
.PURPLE4  = #A855F7
.PURPLE5  = #9333EA
.PURPLE6  = #7E22CE
.PURPLE7  = #6B21A8
.PURPLE8  = #581C87
.PURPLE9  = #3B0764

.FUCHSIA0 = #FAE8FF
.FUCHSIA1 = #F5D0FE
.FUCHSIA2 = #F0ABFC
.FUCHSIA3 = #E879F9
.FUCHSIA4 = #D946EF
.FUCHSIA5 = #C026D3
.FUCHSIA6 = #A21CAF
.FUCHSIA7 = #86198F
.FUCHSIA8 = #701A75
.FUCHSIA9 = #4A044E

.PINK0    = #FCE7F3
.PINK1    = #FBCFE8
.PINK2    = #F9A8D4
.PINK3    = #F472B6
.PINK4    = #EC4899
.PINK5    = #DB2777
.PINK6    = #BE185D
.PINK7    = #9D174D
.PINK8    = #831843
.PINK9    = #500724

.ROSE0    = #FFE4E6
.ROSE1    = #FECDD3
.ROSE2    = #FDA4AF
.ROSE3    = #FB7185
.ROSE4    = #F43F5E
.ROSE5    = #E11D48
.ROSE6    = #BE123C
.ROSE7    = #9F1239
.ROSE8    = #881337
.ROSE9    = #4C0519

}}} */
