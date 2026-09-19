// MS13 Food Trash

// Parent types

/obj/item/trash/ms13
    name = "generic trash"
    desc = "Your mother. LOOK AWAY, THIS DOESN'T EXIST."
    icon = 'mojave/icons/objects/food/prewar_food.dmi'

/obj/item/trash/ms13/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/item_scaling, 0.50, 1)

/obj/item/trash/ms13/cans
    name = "generic can trash"
    desc = "You shouldn't be seeing this, LOOK THE FUCK AWAY."
    icon_state = "generic_can_1_trash"

/obj/item/trash/ms13/packaging
    name = "generic packaging trash"
    desc = "Pack it up boys we did it we found the parent type packaging trash. LOOK AWAY."
    icon_state = "generic_can_3_trash"

// The TRASH
// Can Trash

/obj/item/trash/ms13/cans/dogfood
    name = "dog food"
    desc = "Nothing left for fido in this. It was a dog that ate this, right?"
    icon_state = "dogfood_trash"

/obj/item/trash/ms13/cans/porknbeans
    name = "empty porknbean can"
    desc = "What's a cowboy without his pot of beans?"
    icon_state = "porknbean_trash"

/obj/item/trash/ms13/cans/seafood
    name = "empty seafood can"
    desc = "Nothing left but the smell of the sea. At least, this is probably what the sea smells like."
    icon_state = "seafood_trash"

/obj/item/trash/ms13/cans/cajunrice
    name = "empty cajun rice can"
    desc = "You won't be putting anything onna rollin boil with this."
    icon_state = "cajunrice_trash"

// Packaging Trash

/obj/item/trash/ms13/packaging/salisbury
    name = "empty salisbury box"
    desc = "No more meat and gravy."
    icon_state = "salisbury_trash"

/obj/item/trash/ms13/packaging/crisps
    name = "empty crisps can"
    desc = "No more starchy wafers, you'll need to find your potato-y communion cookies somewhere else."
    icon_state = "crisps_trash"

/obj/item/trash/ms13/packaging/dandy
    name = "empty dandy boy box"
    desc = "A ghoul told you once that they used to bob for these in water on a special day. Who's Bob, and how did these grow in water?"
    icon_state = "dandy_trash"

/obj/item/trash/ms13/packaging/snackcake
    name = "empty fancy lad box"
    desc = "These things last forever, until you eat them. They're all gone now."
    icon_state = "snackcake_trash"

/obj/item/trash/ms13/packaging/macncheese
    name = "empty macncheese box"
    desc = "No more cheesy goodness left, you'll have to look elsewhere for your dairy cravings."
    icon_state = "macncheese_trash"

/obj/item/trash/ms13/packaging/poofs
    name = "empty cheesy poofs box"
    desc = "The poofs have gone poof, there's none left."
    icon_state = "poofs_trash"

/obj/item/trash/ms13/packaging/sugarbombs
    name = "empty sugarbombs box"
    desc = "Despite being named sugarbombs, you don't know how you could make this empty box into an improvised explosive device."
    icon_state = "sugarbombs_trash"

/obj/item/trash/ms13/packaging/yumegg
    name = "empty yum yum deviled eggs box"
    desc = "There's no more devil left in this one."
    icon_state = "yumegg_trash"

/obj/item/trash/ms13/packaging/instamash
    name = "empty instamash box"
    desc = "Someone has, presumably, already insta'd the mash."
    icon_state = "instamash_trash"

/obj/item/trash/ms13/trash_pile
	name = "old trash"
	desc = "garbage"
	icon = 'mojave/imports/secondcity/icons/trash.dmi'
	icon_state = "big1"

/obj/item/trash/ms13/bigtrash/tyres_trash
	name = "old tyres"
	desc = "Three tires stacked on top of eachother"
	icon_state = "big0"

/obj/item/trash/ms13/trash_pile/ac_trash
	name = "old machines"
	desc = "A pile of broken machines"
	icon_state = "big1"

/obj/item/trash/ms13/trash_pile/tyres_trash2
	name = "old tyres"
	desc = "Thee tyres stacked on top of eachother"
	icon_state = "big2"

/obj/item/trash/ms13/trash_pile/trash3
	name = "old metal siding"
	desc = "A pile of broken-down metal sidings"
	icon_state = "big3"

/obj/item/trash/ms13/trash_pile/trash4
	name = "metal scrap"
	desc = "A pile of metal junk"
	icon_state = "big4"

/obj/item/trash/ms13/trash_pile/medtrash0
	name = "bottle trash"
	desc = "Rotten cardboard and bottles"
	icon_state = "medium0"

/obj/item/trash/ms13/trash_pile/medtrash1
	name = "rotting garbage"
	desc = ""
	icon_state = "medium1"

/obj/item/trash/ms13/trash_pile/medtrash2
	name = "worn out saucepans"
	desc = "A pile of worn-out saucepans, looks useless.."
	icon_state = "medium2"

/obj/item/trash/ms13/trash_pile/medtrash3
	name = "broken toilet"
	desc = ""
	icon_state = "medium3"

/obj/item/trash/ms13/trash_pile/medtrash4
	name = "rotting tire"
	desc = ""
	icon_state = "medium4"