#!/bin/sh
# sranime-cli Canonical Story Arc Marathon Engine
#
# Provides built-in story arc databases and episode range selectors for:
#   - One Piece
#   - Naruto
#   - Naruto Shippuden
#   - Bleach
#   - Hunter x Hunter
#   - Dragon Ball Z
#   - Jujutsu Kaisen
#   - Demon Slayer (Kimetsu no Yaiba)
#
# Functions:
#   - arcs_slugify <title>
#   - arcs_has_data <title>
#   - arcs_list <title>
#   - arcs_get_range <title> <query>
#   - arcs_get_name <title> <query>
#   - arcs_get_synopsis <title> <query>
#   - arcs_print_summary <title> <query>
#   - arcs_choose_interactive <title> [menu_program] [menu_flags]

arcs_slugify() {
    _raw="$1"
    _s=$(printf '%s' "$_raw" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//')
    case "$_s" in
        *shippuden*|*shippuuden*) echo "naruto-shippuden" ;;
        *naruto*) echo "naruto" ;;
        *one-piece*|*onepiece*) echo "one-piece" ;;
        *bleach*) echo "bleach" ;;
        *hunter*hunter*|*hxh*) echo "hunter-x-hunter" ;;
        *dragon-ball-z*|*dbz*) echo "dragon-ball-z" ;;
        *jujutsu*kaisen*|*jjk*) echo "jujutsu-kaisen" ;;
        *demon-slayer*|*kimetsu*no*yaiba*) echo "demon-slayer" ;;
        *) echo "$_s" ;;
    esac
}

arcs_has_data() {
    _s=$(arcs_slugify "$1")
    case "$_s" in
        one-piece|naruto|naruto-shippuden|bleach|hunter-x-hunter|dragon-ball-z|jujutsu-kaisen|demon-slayer)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

_arcs_registry() {
    _s="$1"
    case "$_s" in
        one-piece)
            printf "%s\t%s\t%s\t%s\t%s\n" "romance-dawn" "1-3" "Romance Dawn Arc" "3" "Luffy begins his journey, meets Coby and Zoro."
            printf "%s\t%s\t%s\t%s\t%s\n" "orange-town" "4-8" "Orange Town Arc" "5" "Luffy and Zoro battle Buggy the Clown and recruit Nami."
            printf "%s\t%s\t%s\t%s\t%s\n" "syrup-village" "9-18" "Syrup Village Arc" "10" "The Straw Hats meet Usopp and defend Kaya from Captain Kuro."
            printf "%s\t%s\t%s\t%s\t%s\n" "baratie" "19-30" "Baratie Arc" "12" "Luffy meets Sanji aboard the floating restaurant and battles Don Krieg."
            printf "%s\t%s\t%s\t%s\t%s\n" "arlong-park" "31-44" "Arlong Park Arc" "14" "The crew fights the Arlong Pirates to free Nami and her hometown."
            printf "%s\t%s\t%s\t%s\t%s\n" "loguetown" "45-53" "Loguetown Arc" "9" "The Straw Hats visit the town where Gold Roger was executed."
            printf "%s\t%s\t%s\t%s\t%s\n" "reverse-mountain" "62-67" "Reverse Mountain & Whiskey Peak Arc" "6" "Entering the Grand Line, meeting Laboon and Princess Vivi."
            printf "%s\t%s\t%s\t%s\t%s\n" "little-garden" "70-77" "Little Garden Arc" "8" "The crew lands on a prehistoric island and clashes with Baroque Works."
            printf "%s\t%s\t%s\t%s\t%s\n" "drum-island" "78-91" "Drum Island Arc" "14" "Seeking a doctor for Nami, Luffy recruits Tony Tony Chopper."
            printf "%s\t%s\t%s\t%s\t%s\n" "alabasta" "92-130" "Alabasta Arc" "39" "Luffy clashes with Crocodile to save the desert kingdom of Alabasta."
            printf "%s\t%s\t%s\t%s\t%s\n" "jaya" "144-152" "Jaya Arc" "9" "Luffy encounters Blackbeard and Bellamy and learns how to reach the sky."
            printf "%s\t%s\t%s\t%s\t%s\n" "skypiea" "153-195" "Skypiea Arc" "43" "The Straw Hats voyage to the sky island and clash with the god Enel."
            printf "%s\t%s\t%s\t%s\t%s\n" "g-8" "196-206" "G-8 Navarone Arc (Fan Favorite)" "11" "The Straw Hats navigate out of Vice Admiral Jonathan's Marine fortress."
            printf "%s\t%s\t%s\t%s\t%s\n" "long-ring-long-land" "207-219" "Long Ring Long Land Arc" "13" "The Davy Back Fight against Foxy the Silver Fox."
            printf "%s\t%s\t%s\t%s\t%s\n" "water-7" "229-263" "Water 7 Arc" "35" "The crew travels to the water metropolis; CP9 frames the crew and captures Robin."
            printf "%s\t%s\t%s\t%s\t%s\n" "enies-lobby" "264-312" "Enies Lobby Arc" "49" "Declaration of war on the World Government to rescue Nico Robin."
            printf "%s\t%s\t%s\t%s\t%s\n" "post-enies-lobby" "313-325" "Post-Enies Lobby Arc" "13" "Luffy's grandfather Garp arrives; Franky builds the Thousand Sunny."
            printf "%s\t%s\t%s\t%s\t%s\n" "thriller-bark" "337-381" "Thriller Bark Arc" "45" "The crew enters the Florian Triangle, encounters Brook, and battles Gecko Moria."
            printf "%s\t%s\t%s\t%s\t%s\n" "sabaody" "385-405" "Sabaody Archipelago Arc" "21" "The Supernovas gather; Celestial Dragons provoked; Kuma separates the crew."
            printf "%s\t%s\t%s\t%s\t%s\n" "amazon-lily" "408-421" "Amazon Lily Arc" "14" "Luffy lands on the island of women ruled by Warlord Boa Hancock."
            printf "%s\t%s\t%s\t%s\t%s\n" "impel-down" "422-452" "Impel Down Arc" "31" "Luffy infiltrates the maximum-security undersea prison to rescue Ace."
            printf "%s\t%s\t%s\t%s\t%s\n" "marineford" "457-489" "Marineford Paramount War Arc" "33" "The Whitebeard Pirates wage war on Marine Headquarters to rescue Ace."
            printf "%s\t%s\t%s\t%s\t%s\n" "post-war" "490-516" "Post-War Arc" "27" "Luffy and Ace's childhood flashback; the 3D2Y secret code message."
            printf "%s\t%s\t%s\t%s\t%s\n" "return-to-sabaody" "517-522" "Return to Sabaody Arc" "6" "Two years later, the Straw Hats reunite in Sabaody with new powers."
            printf "%s\t%s\t%s\t%s\t%s\n" "fish-man-island" "523-574" "Fish-Man Island Arc" "52" "The crew dives 10,000 meters beneath the sea to Fish-Man Island."
            printf "%s\t%s\t%s\t%s\t%s\n" "punk-hazard" "579-628" "Punk Hazard Arc" "50" "Luffy forms an alliance with Trafalgar Law against Caesar Clown."
            printf "%s\t%s\t%s\t%s\t%s\n" "dressrosa" "629-746" "Dressrosa Arc" "118" "The Straw Hats and allies challenge Donquixote Doflamingo to free Dressrosa."
            printf "%s\t%s\t%s\t%s\t%s\n" "zou" "751-779" "Zou Arc" "29" "The crew reunites on the giant elephant Zou and learns of the Road Poneglyphs."
            printf "%s\t%s\t%s\t%s\t%s\n" "whole-cake-island" "783-877" "Whole Cake Island Arc" "95" "Infiltrating Big Mom's territory to retrieve Sanji and copy Poneglyphs."
            printf "%s\t%s\t%s\t%s\t%s\n" "reverie" "878-891" "Reverie (Levely) Arc" "14" "World leaders convene at Mary Geoise as revolutionary sparks ignite."
            printf "%s\t%s\t%s\t%s\t%s\n" "wano" "892-1085" "Wano Country Arc" "194" "The epic raid on Onigashima to overthrow Emperors Kaido and Big Mom."
            printf "%s\t%s\t%s\t%s\t%s\n" "egghead" "1086-1122" "Egghead Island Arc" "37" "The future island of Dr. Vegapunk and the arrival of the Five Elders."
            ;;
        naruto)
            printf "%s\t%s\t%s\t%s\t%s\n" "land-of-waves" "1-19" "Land of Waves Arc" "19" "Team 7 guards Tazuna and battles rogue ninja Zabuza and Haku."
            printf "%s\t%s\t%s\t%s\t%s\n" "chunin-exams" "20-67" "Chunin Exams Arc" "48" "Genin from all nations compete in the Forest of Death and tournament arena."
            printf "%s\t%s\t%s\t%s\t%s\n" "konoha-crush" "68-80" "Konoha Crush Arc" "13" "Orochimaru invades the Hidden Leaf Village; Third Hokage's sacrifice."
            printf "%s\t%s\t%s\t%s\t%s\n" "search-for-tsunade" "81-100" "Search for Tsunade Arc" "20" "Jiraiya and Naruto search for Tsunade to become the Fifth Hokage."
            printf "%s\t%s\t%s\t%s\t%s\n" "sasuke-recovery" "107-135" "Sasuke Recovery Mission Arc" "29" "Shikamaru leads genin to retrieve Sasuke from the Sound Four."
            ;;
        naruto-shippuden)
            printf "%s\t%s\t%s\t%s\t%s\n" "kazekage-rescue" "1-32" "Kazekage Rescue Mission Arc" "32" "Team Kakashi and Granny Chiyo rescue Gaara from Sasori and Deidara."
            printf "%s\t%s\t%s\t%s\t%s\n" "tenchi-bridge" "33-53" "Tenchi Bridge Reconnaissance Arc" "21" "New Team 7 encounters Orochimaru, Kabuto, and Sasuke at Tenchi Bridge."
            printf "%s\t%s\t%s\t%s\t%s\n" "twelve-guardian-ninja" "54-71" "Twelve Guardian Ninja Arc" "18" "Naruto trains his Wind style; Sora and the Fire Temple conspiracy."
            printf "%s\t%s\t%s\t%s\t%s\n" "hidan-and-kakuzu" "72-88" "Immortal Devastators: Hidan and Kakuzu Arc" "17" "Team 10 seeks vengeance for Asuma; Naruto masters Rasenshuriken."
            printf "%s\t%s\t%s\t%s\t%s\n" "three-tails" "89-112" "Three-Tails' Appearance Arc" "24" "Leaf ninja battle Guren to seal the Three-Tails Isobu."
            printf "%s\t%s\t%s\t%s\t%s\n" "itachi-pursuit" "113-126" "Itachi Pursuit Mission Arc" "14" "Sasuke forms Hebi; Eight-man squad hunts for Itachi."
            printf "%s\t%s\t%s\t%s\t%s\n" "tale-of-jiraiya" "127-133" "Tale of Jiraiya the Gallant Arc" "7" "Jiraiya infiltrates the Hidden Rain Village and fights Pain."
            printf "%s\t%s\t%s\t%s\t%s\n" "fated-battle" "134-143" "Fated Battle Between Brothers Arc" "10" "Sasuke vs. Itachi; the truth about the Uchiha massacre revealed."
            printf "%s\t%s\t%s\t%s\t%s\n" "six-tails" "144-151" "Six-Tails Unleashed Arc" "8" "Naruto protects Utakata, the Jinchuriki of the Six-Tails Saiken."
            printf "%s\t%s\t%s\t%s\t%s\n" "pains-assault" "152-175" "Pain's Assault Arc" "24" "Pain destroys Konoha; Sage Mode Naruto returns to defend the village."
            printf "%s\t%s\t%s\t%s\t%s\n" "five-kage-summit" "197-214" "Five Kage Summit Arc" "18" "Leaders gather in Land of Iron; Tobi declares Fourth Great Ninja War."
            printf "%s\t%s\t%s\t%s\t%s\n" "confining-the-jinchuriki" "243-256" "Confining the Jinchuriki Arc" "14" "Naruto trains on Turtle Island with Killer Bee to control Kurama."
            printf "%s\t%s\t%s\t%s\t%s\n" "shinobi-war-countdown" "257-260" "Fourth Shinobi World War: Countdown Arc" "4" "Allied Shinobi Forces assemble against the Reanimation army."
            printf "%s\t%s\t%s\t%s\t%s\n" "shinobi-war-confrontation" "261-321" "Fourth Shinobi World War: Confrontation Arc" "61" "Battles against reanimated legendary shinobi on all fronts."
            printf "%s\t%s\t%s\t%s\t%s\n" "shinobi-war-climax" "322-375" "Fourth Shinobi World War: Climax Arc" "54" "Madara Uchiha enters the battlefield; Ten-Tails is summoned."
            printf "%s\t%s\t%s\t%s\t%s\n" "ten-tails-jinchuriki" "378-426" "Birth of the Ten-Tails' Jinchuriki Arc" "49" "Obito and Madara become Ten-Tails jinchuriki; Eight Gates Might Guy."
            printf "%s\t%s\t%s\t%s\t%s\n" "kaguya-strikes" "451-479" "Kaguya Otsutsuki Strikes Arc" "29" "Team 7 seals the progenitor of chakra; Naruto vs. Sasuke final battle."
            ;;
        bleach)
            printf "%s\t%s\t%s\t%s\t%s\n" "substitute-shinigami" "1-20" "The Substitute Shinigami Arc" "20" "Ichigo gains soul reaper powers and defends Karakura Town from Hollows."
            printf "%s\t%s\t%s\t%s\t%s\n" "soul-society-sneak-entry" "21-41" "Soul Society: The Sneak Entry Arc" "21" "Ichigo and friends breach the Seireitei to rescue Rukia Kuchiki."
            printf "%s\t%s\t%s\t%s\t%s\n" "soul-society-the-rescue" "42-63" "Soul Society: The Rescue Arc" "22" "Bankai unlocked; captains clash; Sosuke Aizen reveals his betrayal."
            printf "%s\t%s\t%s\t%s\t%s\n" "bount" "64-109" "The Bount Arc" "46" "Immortal soul-consuming Bounts threaten Karakura Town and Soul Society."
            printf "%s\t%s\t%s\t%s\t%s\n" "arrancar-arrival" "110-131" "Arrancar: The Arrival Arc" "22" "Ulquiorra and Yammy invade; Visored teach Ichigo Hollowfication."
            printf "%s\t%s\t%s\t%s\t%s\n" "hueco-mundo-entry" "132-151" "Arrancar: Hueco Mundo Sneak Entry Arc" "20" "Ichigo, Uryu, and Chad storm Las Noches to rescue Orihime."
            printf "%s\t%s\t%s\t%s\t%s\n" "the-fierce-fight" "152-167" "Arrancar: The Fierce Fight Arc" "16" "Duels against the Espada in Las Noches."
            printf "%s\t%s\t%s\t%s\t%s\n" "shusuke-amagai" "168-189" "The New Captain Shusuke Amagai Arc" "22" "Captain Amagai arrives as Kasumioji family bakkoto weapons emerge."
            printf "%s\t%s\t%s\t%s\t%s\n" "arrancar-vs-shinigami" "190-205" "Arrancar vs. Shinigami Arc" "16" "Kenpachi, Byakuya, and captains reinforce Hueco Mundo."
            printf "%s\t%s\t%s\t%s\t%s\n" "the-past" "206-212" "The Past Arc (Turn Back the Pendulum)" "7" "Flashback to 110 years ago: Urahara, Yoruichi, and Visored origins."
            printf "%s\t%s\t%s\t%s\t%s\n" "decisive-battle-karakura" "213-229" "Arrancar: Decisive Battle of Karakura Arc" "17" "Captains clash with top three Espada in the fake town."
            printf "%s\t%s\t%s\t%s\t%s\n" "zanpakuto-unknown-tales" "230-265" "Zanpakuto Unknown Tales Arc" "36" "Muramasa frees Zanpakuto spirits who rebel against Soul Reapers."
            printf "%s\t%s\t%s\t%s\t%s\n" "arrancar-downfall" "266-316" "Arrancar: Downfall Arc" "51" "Vasto Lorde Ichigo vs. Ulquiorra; Final Getsuga Tensho vs. Aizen."
            printf "%s\t%s\t%s\t%s\t%s\n" "gotei-13-invading-army" "317-342" "Gotei 13 Invading Army Arc" "26" "Reigai impostor captains replace the Gotei 13."
            printf "%s\t%s\t%s\t%s\t%s\n" "fullbring" "343-366" "The Lost Substitute Shinigami (Fullbring) Arc" "24" "Ichigo joins Xcution to regain his lost Soul Reaper powers."
            printf "%s\t%s\t%s\t%s\t%s\n" "thousand-year-blood-war" "367-392" "Thousand-Year Blood War Arc" "26" "Yhwach and the Quincy Wandenreich declare war on Soul Society."
            ;;
        hunter-x-hunter)
            printf "%s\t%s\t%s\t%s\t%s\n" "hunter-exam" "1-26" "Hunter Exam Arc" "26" "Gon, Killua, Kurapika, and Leorio undertake the perilous Hunter Exam."
            printf "%s\t%s\t%s\t%s\t%s\n" "zoldyck-and-heavens-arena" "27-36" "Zoldyck Family & Heavens Arena Arc" "10" "Rescuing Killua from Kukuroo Mountain and mastering Nen at Heavens Arena."
            printf "%s\t%s\t%s\t%s\t%s\n" "yorknew-city" "37-58" "Yorknew City Arc (Phantom Troupe)" "22" "Kurapika hunts the Spiders as the underground mafia auction unravels."
            printf "%s\t%s\t%s\t%s\t%s\n" "greed-island" "59-75" "Greed Island Arc" "17" "Gon and Killua enter Ging's real-life RPG game and train with Biscuit Krueger."
            printf "%s\t%s\t%s\t%s\t%s\n" "chimera-ant" "76-136" "Chimera Ant Arc" "61" "The royal expedition into NGL against Chimera Ants and King Meruem."
            printf "%s\t%s\t%s\t%s\t%s\n" "election" "137-148" "13th Hunter Chairman Election Arc" "12" "The Zodiacs contest the chairmanship while Killua saves Gon with Alluka."
            ;;
        dragon-ball-z)
            printf "%s\t%s\t%s\t%s\t%s\n" "saiyan-saga" "1-35" "Saiyan Saga" "35" "Raditz, Nappa, and Vegeta invade Earth; Goku learns Kaio-ken and Spirit Bomb."
            printf "%s\t%s\t%s\t%s\t%s\n" "frieza-saga" "36-107" "Namek & Frieza Saga" "72" "The quest for Namekian Dragon Balls; Goku turns Super Saiyan."
            printf "%s\t%s\t%s\t%s\t%s\n" "garlic-jr" "108-117" "Garlic Jr. Saga" "10" "Garlic Jr. escapes the Dead Zone and infects Earth with Black Water Mist."
            printf "%s\t%s\t%s\t%s\t%s\n" "cell-saga" "118-194" "Androids & Cell Saga" "77" "Future Trunks warns of Androids; Gohan achieves Super Saiyan 2."
            printf "%s\t%s\t%s\t%s\t%s\n" "other-world" "195-199" "Other World Tournament Saga" "5" "Goku competes in King Kai's tournament against Pikkon."
            printf "%s\t%s\t%s\t%s\t%s\n" "majin-buu-saga" "200-291" "Majin Buu Saga" "92" "Babidi awakens Majin Buu; Fusion, Super Saiyan 3, and the Super Spirit Bomb."
            ;;
        jujutsu-kaisen)
            printf "%s\t%s\t%s\t%s\t%s\n" "fearsome-womb" "1-13" "Introduction & Vs. Mahito Arc" "13" "Yuji swallows Sukuna's finger and enters Jujutsu High; clash with Mahito."
            printf "%s\t%s\t%s\t%s\t%s\n" "kyoto-goodwill" "14-21" "Kyoto Goodwill Event Arc" "8" "Tokyo and Kyoto sister schools compete as Special Grade curses ambush."
            printf "%s\t%s\t%s\t%s\t%s\n" "death-painting" "22-24" "Death Painting Arc (Origin of Obedience)" "3" "Yuji, Megumi, and Nobara investigate Yasohachi Bridge and the Cursed Wombs."
            printf "%s\t%s\t%s\t%s\t%s\n" "hidden-inventory" "25-29" "Hidden Inventory / Premature Death Arc" "5" "Gojo and Geto's youth escorting the Star Plasma Vessel Riko Amanai."
            printf "%s\t%s\t%s\t%s\t%s\n" "shibuya-incident" "30-47" "Shibuya Incident Arc" "18" "The Halloween curse plot in Shibuya subway; Gojo Satoru sealed."
            ;;
        demon-slayer)
            printf "%s\t%s\t%s\t%s\t%s\n" "final-selection" "1-5" "Final Selection Arc" "5" "Tanjiro trains under Urokodaki and survives Mount Fujikasane."
            printf "%s\t%s\t%s\t%s\t%s\n" "first-mission" "6-14" "Asakusa & Tsuzumi Mansion Arc" "9" "Tanjiro meets Muzan Kibutsuji, Tamayo, Zenitsu, and Inosuke."
            printf "%s\t%s\t%s\t%s\t%s\n" "mount-natagumo" "15-21" "Mount Natagumo Arc" "7" "Battle against Rui and Spider Family; Hinokami Kagura awakened."
            printf "%s\t%s\t%s\t%s\t%s\n" "rehabilitation" "22-26" "Rehabilitation Training Arc" "5" "The Hashira meeting and Total Concentration Constant training."
            printf "%s\t%s\t%s\t%s\t%s\n" "mugen-train" "27-33" "Mugen Train Arc (TV Series)" "7" "Tanjiro, Zenitsu, and Inosuke join Flame Hashira Rengoku Kyojuro."
            printf "%s\t%s\t%s\t%s\t%s\n" "entertainment-district" "34-44" "Entertainment District Arc" "11" "Sound Hashira Tengen Uzui and Tanjiro battle Upper Rank Six Gyutaro."
            printf "%s\t%s\t%s\t%s\t%s\n" "swordsmith-village" "45-55" "Swordsmith Village Arc" "11" "Tanjiro, Muichiro, and Mitsuri defend village from Hantengu and Gyokko."
            printf "%s\t%s\t%s\t%s\t%s\n" "hashira-training" "56-63" "Hashira Training Arc" "8" "Demon Slayer Corps undertakes intensive training under all surviving Hashira."
            ;;
    esac
}

arcs_list() {
    _s=$(arcs_slugify "$1")
    _arcs_registry "$_s"
}

_arcs_find_entry() {
    _title="$1"
    _query="$2"
    _s=$(arcs_slugify "$_title")
    [ -z "$_s" ] && return 1

    _q_clean=$(printf '%s' "$_query" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//')

    # 1. Exact match on slug
    _match=$(arcs_list "$_title" | awk -F'\t' -v q="$_q_clean" '$1 == q { print $0; exit }')
    if [ -n "$_match" ]; then
        printf "%s\n" "$_match"
        return 0
    fi

    # 2. Substring match on slug
    _match=$(arcs_list "$_title" | awk -F'\t' -v q="$_q_clean" 'index($1, q) > 0 { print $0; exit }')
    if [ -n "$_match" ]; then
        printf "%s\n" "$_match"
        return 0
    fi

    # 3. Case-insensitive substring match on arc name
    _q_lower=$(printf '%s' "$_query" | tr '[:upper:]' '[:lower:]')
    _match=$(arcs_list "$_title" | awk -F'\t' -v q="$_q_lower" 'index(tolower($3), q) > 0 { print $0; exit }')
    if [ -n "$_match" ]; then
        printf "%s\n" "$_match"
        return 0
    fi

    return 1
}

arcs_get_range() {
    _entry=$(_arcs_find_entry "$1" "$2")
    if [ -n "$_entry" ]; then
        printf "%s\n" "$_entry" | cut -f 2
        return 0
    fi
    return 1
}

arcs_get_name() {
    _entry=$(_arcs_find_entry "$1" "$2")
    if [ -n "$_entry" ]; then
        printf "%s\n" "$_entry" | cut -f 3
        return 0
    fi
    return 1
}

arcs_get_synopsis() {
    _entry=$(_arcs_find_entry "$1" "$2")
    if [ -n "$_entry" ]; then
        printf "%s\n" "$_entry" | cut -f 5
        return 0
    fi
    return 1
}

arcs_print_summary() {
    _title="$1"
    _query="$2"
    _entry=$(_arcs_find_entry "$_title" "$_query")
    if [ -z "$_entry" ]; then
        printf "\033[1;31m[Story Arc] No matching story arc found for query: %s\033[0m\n" "$_query" >&2
        return 1
    fi

    _range=$(printf "%s" "$_entry" | cut -f 2)
    _name=$(printf "%s" "$_entry" | cut -f 3)
    _count=$(printf "%s" "$_entry" | cut -f 4)
    _synopsis=$(printf "%s" "$_entry" | cut -f 5)

    printf "\033[1;35m╭────────────────────────────────────────────────────────────────────────╮\033[0m\n"
    printf "\033[1;35m│\033[0m \033[1;33m[STORY ARC MARATHON]\033[0m \033[1;37m%-48s\033[0m \033[1;35m│\033[0m\n" "$_name"
    printf "\033[1;35m├────────────────────────────────────────────────────────────────────────┤\033[0m\n"
    printf "\033[1;35m│\033[0m \033[1;36mSeries:\033[0m    %-57s \033[1;35m│\033[0m\n" "$_title"
        _start=$(printf "%s" "$_range" | cut -d'-' -f1)
    _end=$(printf "%s" "$_range" | cut -d'-' -f2)
    printf "\033[1;35m│\033[0m \033[1;36mEpisodes:\033[0m  Episodes %s - %s (%s episodes total)\033[0m\n" "$_start" "$_end" "$_count"
    printf "\033[1;35m│\033[0m \033[1;36mSynopsis:\033[0m  %-57s \033[1;35m│\033[0m\n" "$_synopsis"
    printf "\033[1;35m╰────────────────────────────────────────────────────────────────────────╯\033[0m\n"
    return 0
}

arcs_choose_interactive() {
    _title="$1"
    _menu_cmd="${2:-fzf}"
    _menu_flags="${3:-}"

    if ! arcs_has_data "$_title"; then
        printf "\033[1;33m[Story Arcs] No built-in arc registry found for '%s'.\033[0m\n" "$_title" >&2
        return 1
    fi

    _formatted=$(arcs_list "$_title" | awk -F'\t' '{ printf "%-10s  |  %-36s (%s eps)\n", $2, $3, $4 }')
    
    if command -v "$_menu_cmd" >/dev/null 2>&1; then
        _picked=$(printf "%s\n" "$_formatted" | "$_menu_cmd" --prompt="Select Story Arc: " $_menu_flags)
    else
        printf "\nAvailable Story Arcs for %s:\n" "$_title"
        printf "%s\n" "$_formatted" | nl -w 2 -s ') '
        printf "Enter number or range: "
        read -r _choice
        if printf "%s" "$_choice" | grep -q '^[0-9]\+$'; then
            _picked=$(printf "%s\n" "$_formatted" | sed -n "${_choice}p")
        else
            _picked="$_choice"
        fi
    fi

    [ -z "$_picked" ] && return 1

    # Extract the episode range (e.g. 457-489)
    _range=$(printf "%s" "$_picked" | awk '{print $1}' | tr -d '[:space:]')
    printf "%s\n" "$_range"
    return 0
}
