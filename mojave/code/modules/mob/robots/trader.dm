// AI EDIT: restored - this file was deleted in an earlier pass as a "duplicate of DD's own trader.dm", but that
// was wrong: DD's trader.dm (code/modules/mob/living/simple_animal/friendly/trader.dm) is a simpler, incompatible
// reimplementation of the same base type (no per-item stock counts, no multi-phrase flavor text, no custom
// currency, and its buy_item()/try_buy() split doesn't match what this file's overrides expect), and
// vendortrons.dm's 10 vendortron subtypes depend entirely on this richer framework. Restoring it onto the shared
// base type (like the original did) would duplicate-conflict with DD's own var declarations on that same path, so
// everything below is scoped to the /ms13 subtype instead, which only adds new vars/procs and fully overrides the
// handful it shares a name with (normal subtyping, not a redeclaration conflict). Dropped from the original:
// the node-based restock/patrol movement system (nothing in mojave/ ever used it) and two FO-style
// throw_alert_text() calls (that proc doesn't exist in DD - the matching say() line already conveys the same info).
#define ITEM_REJECTED_PHRASE "ITEM_REJECTED_PHRASE"
#define ITEM_SELLING_CANCELED_PHRASE "ITEM_SELLING_CANCELED_PHRASE"
#define ITEM_SELLING_ACCEPTED_PHRASE "ITEM_SELLING_ACCEPTED_PHRASE"
#define INTERESTED_PHRASE "INTERESTED_PHRASE"
#define BUY_PHRASE "BUY_PHRASE"
#define NO_CASH_PHRASE "NO_CASH_PHRASE"
#define NO_STOCK_PHRASE "NO_STOCK_PHRASE"
#define NOT_WILLING_TO_BUY_PHRASE "NOT_WILLING_TO_BUY_PHRASE"
#define ITEM_IS_WORTHLESS_PHRASE "ITEM_IS_WORTHLESS_PHRASE"
#define TRADER_HAS_ENOUGH_ITEM_PHRASE "TRADER_HAS_ENOUGH_ITEM_PHRASE"
#define TRADER_LORE_PHRASE "TRADER_LORE_PHRASE"
#define TRADER_NOT_BUYING_ANYTHING "TRADER_NOT_BUYING_ANYTHING"
#define TRADER_NOT_SELLING_ANYTHING "TRADER_NOT_SELLING_ANYTHING"

#define TRADER_PRODUCT_INFO_PRICE 1
#define TRADER_PRODUCT_INFO_QUANTITY 2
///Only valid for wanted_items
#define TRADER_PRODUCT_INFO_PRICE_MOD_DESCRIPTION 3

/mob/living/simple_animal/hostile/retaliate/trader/ms13
	///What type of currency this trader uses for buying and selling, MS13 addition
	var/accepted_currency = /obj/item/stack/ms13/currency
	///The name of the currency that is used when buying or selling items
	var/currency_name = "credits"
	///Associated list of defines matched with list of phrases; phrase to be said is dealt by return_trader_phrase()
	var/list/say_phrases = list(
		ITEM_REJECTED_PHRASE = list(
			"Sorry, I'm not a fan of anything you're showing me. Give me something better and we'll talk."
		),
		ITEM_SELLING_CANCELED_PHRASE = list(
			"What a shame, tell me if you changed your mind."
		),
		ITEM_SELLING_ACCEPTED_PHRASE = list(
			"Pleasure doing business with you."
		),
		INTERESTED_PHRASE = list(
			"Hey, you've got an item that interests me, I'd like to buy it, I'll give you some cash for it, deal?"
		),
		BUY_PHRASE = list(
			"Pleasure doing business with you."
		),
		NO_CASH_PHRASE = list(
			"Sorry adventurer, I can't give credit! Come back when you're a little mmmmm... richer!"
		),
		NO_STOCK_PHRASE = list(
			"Sorry adventurer, but that item is not in stock at the moment."
		),
		NOT_WILLING_TO_BUY_PHRASE = list(
			"I don't want to buy that item for the time being, check back another time."
		),
		ITEM_IS_WORTHLESS_PHRASE = list(
			"This item seems to be worthless on a closer look, I won't buy this."
		),
		TRADER_HAS_ENOUGH_ITEM_PHRASE = list(
			"I already bought enough of this for the time being."
		),
		TRADER_LORE_PHRASE = list(
			"Hello! I am the test trader.",
			"Oooooooo~!"
		),
		TRADER_NOT_BUYING_ANYTHING = list(
			"I'm currently buying nothing at the moment."
		),
		TRADER_NOT_SELLING_ANYTHING = list(
			"I'm currently selling nothing at the moment."
		),
	)

///Initializes the products and item demands of the trader
/mob/living/simple_animal/hostile/retaliate/trader/ms13/Initialize(mapload)
	. = ..()
	restock_products()
	renew_item_demands()

///Returns a list of the starting price/quantity/fluff text about the product listings; products = initial(products) doesn't work so this exists mainly for restock_products()
/mob/living/simple_animal/hostile/retaliate/trader/ms13/proc/initial_products()
	return list()

///Returns a list of the starting price/quantity/fluff text about the wanted items; wanted_items = initial(wanted_items) doesn't work so this exists mainly for renew_item_demands()
/mob/living/simple_animal/hostile/retaliate/trader/ms13/proc/initial_wanteds()
	return list()

///Sets quantity of all products to initial(quantity)
/mob/living/simple_animal/hostile/retaliate/trader/ms13/proc/restock_products()
	products = initial_products()

///Sets quantity of all wanted_items to initial(quantity)
/mob/living/simple_animal/hostile/retaliate/trader/ms13/proc/renew_item_demands()
	wanted_items = initial_wanteds()

/**
 * Depending on the passed parameter/override, returns a randomly picked string out of a list
 *
 * Do note when overriding this argument, you will need to ensure pick(the list) doesn't get supplied with a list of zero length
 * Arguments:
 * * say_text - (String) a define that matches the key of a entry in say_phrases
 */
/mob/living/simple_animal/hostile/retaliate/trader/ms13/proc/return_trader_phrase(say_text)
	if(!length(say_phrases[say_text]))
		return
	return pick(say_phrases[say_text])

///Sets up the radials for the user and calls procs related to the actions the user wants to take
/mob/living/simple_animal/hostile/retaliate/trader/ms13/interact(mob/user)
	if(user == target)
		return FALSE
	var/list/npc_options = list()
	if(products.len)
		npc_options["Buy"] = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_buy")
	if(length(say_phrases[TRADER_LORE_PHRASE]))
		npc_options["Talk"] = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_talk")
	if(wanted_items.len)
		npc_options["Sell"] = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_sell")
	if(!npc_options.len)
		return FALSE
	var/npc_result = show_radial_menu(user, src, npc_options, custom_check = CALLBACK(src, PROC_REF(check_menu), user), require_near = TRUE, tooltips = TRUE)
	face_atom(user)
	switch(npc_result)
		if("Buy")
			buy_item(user)
		if("Sell")
			try_sell(user)
		if("Talk")
			say(return_trader_phrase(TRADER_LORE_PHRASE))
	return TRUE

///Displays to the user what the trader is willing to buy and how much until a restock happens
/mob/living/simple_animal/hostile/retaliate/trader/ms13/proc/trader_buys_what(mob/user)
	if(!wanted_items.len)
		say(return_trader_phrase(TRADER_NOT_BUYING_ANYTHING))
		return
	var/list/product_info
	to_chat(user, span_green("I'm willing to buy the following; "))
	for(var/obj/item/thing as anything in wanted_items)
		product_info = wanted_items[thing]
		var/tern_op_result = (product_info[TRADER_PRODUCT_INFO_QUANTITY] == INFINITY ? "as many as I can." : "[product_info[TRADER_PRODUCT_INFO_QUANTITY]]")
		if(product_info[TRADER_PRODUCT_INFO_QUANTITY] <= 0)
			to_chat(user, span_notice("[span_red("(DOESN'T WANT MORE)")] [initial(thing.name)] for [product_info[TRADER_PRODUCT_INFO_PRICE]] [currency_name][product_info[TRADER_PRODUCT_INFO_PRICE_MOD_DESCRIPTION]]; willing to buy [span_red("[tern_op_result]")] more."))
		else
			to_chat(user, span_notice("[initial(thing.name)] for [product_info[TRADER_PRODUCT_INFO_PRICE]] [currency_name][product_info[TRADER_PRODUCT_INFO_PRICE_MOD_DESCRIPTION]]; willing to buy [span_green("[tern_op_result]")]"))

///Displays to the user what the trader is selling and how much is in stock
/mob/living/simple_animal/hostile/retaliate/trader/ms13/proc/trader_sells_what(mob/user)
	if(!products.len)
		say(return_trader_phrase(TRADER_NOT_SELLING_ANYTHING))
		return
	var/list/product_info
	to_chat(user, span_green("I'm currently selling the following; "))
	for(var/obj/item/thing as anything in products)
		product_info = products[thing]
		var/tern_op_result = (product_info[TRADER_PRODUCT_INFO_QUANTITY] == INFINITY ? "an infinite amount" : "[product_info[TRADER_PRODUCT_INFO_QUANTITY]]")
		if(product_info[TRADER_PRODUCT_INFO_QUANTITY] <= 0)
			to_chat(user, span_notice("[span_red("(OUT OF STOCK)")] [initial(thing.name)] for [product_info[TRADER_PRODUCT_INFO_PRICE]] [currency_name]; [span_red("[tern_op_result]")] left in stock"))
		else
			to_chat(user, span_notice("[initial(thing.name)] for [product_info[TRADER_PRODUCT_INFO_PRICE]] [currency_name]; [span_green("[tern_op_result]")] left in stock"))

/**
 * Generates a radial of the items the NPC sells and lets the user try to buy one
 * Arguments:
 * * user - (Mob REF) The mob trying to buy something
 */
/mob/living/simple_animal/hostile/retaliate/trader/ms13/buy_item(mob/user)
	if(!LAZYLEN(products))
		return
	var/list/display_names = list()
	var/list/items = list()
	for(var/obj/item/thing as anything in products)
		display_names["[initial(thing.name)]"] = thing
		var/image/item_image = image(icon = initial(thing.icon), icon_state = initial(thing.icon_state))
		items += list("[initial(thing.name)]" = item_image)
	var/pick = show_radial_menu(user, src, items, custom_check = CALLBACK(src, PROC_REF(check_menu), user), require_near = TRUE, tooltips = TRUE)
	if(!pick)
		return
	var/obj/item/item_to_buy = display_names[pick]
	var/list/product_info = products[item_to_buy]
	if(!product_info[TRADER_PRODUCT_INFO_QUANTITY])
		say("[initial(item_to_buy.name)] appears to be out of stock.")
		return
	say("It will cost you [product_info[TRADER_PRODUCT_INFO_PRICE]] [currency_name] to buy \the [initial(item_to_buy.name)]. Are you sure you want to buy it?")
	var/list/npc_options = list(
		"Yes" = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_yes"),
		"No" = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_no")
	)
	var/buyer_will_buy = show_radial_menu(user, src, npc_options, custom_check = CALLBACK(src, PROC_REF(check_menu), user), require_near = TRUE, tooltips = TRUE)
	if(buyer_will_buy != "Yes")
		return
	face_atom(user)
	if(!spend_buyer_offhand_money(user, product_info[TRADER_PRODUCT_INFO_PRICE]))
		say(return_trader_phrase(NO_CASH_PHRASE))
		return
	item_to_buy = new item_to_buy(get_turf(user))
	user.put_in_hands(item_to_buy)
	playsound(src, sell_sound, 50, TRUE)
	product_info[TRADER_PRODUCT_INFO_QUANTITY] -= 1
	say(return_trader_phrase(BUY_PHRASE))

///Calculates the value of money in the hand of the buyer and spends it if it's sufficient
/mob/living/simple_animal/hostile/retaliate/trader/ms13/proc/spend_buyer_offhand_money(mob/user, the_cost)
	var/obj/item/stack/ms13/currency/cash = user.is_holding_item_of_type(accepted_currency)
	if(!cash || cash.amount < the_cost)
		return FALSE
	return cash.use(the_cost)

/**
 * Tries to call sell_item on one of the user's held items, if fail gives a chat message
 * Arguments:
 * * user - (Mob REF) The mob trying to sell something
 */
/mob/living/simple_animal/hostile/retaliate/trader/ms13/try_sell(mob/user)
	var/sold_item = FALSE
	for(var/obj/item/an_item in user.held_items)
		if(sell_item(user, an_item))
			sold_item = TRUE
			break
	if(!sold_item)
		say(return_trader_phrase(ITEM_REJECTED_PHRASE))

/**
 * Checks if an item is in the list of wanted items and if it is after a Yes/No radial returns generate_cash with the value of the item for the NPC
 * Arguments:
 * * user - (Mob REF) The mob trying to sell something
 * * selling - (Item REF) The item being sold
 */
/mob/living/simple_animal/hostile/retaliate/trader/ms13/sell_item(mob/user, obj/item/selling)
	var/cost
	if(!selling)
		return FALSE
	var/list/product_info
	var/typepath_for_product_info
	if(selling.type in wanted_items)
		product_info = wanted_items[selling.type]
		typepath_for_product_info = selling.type
	else
		for(var/typepath in wanted_items)
			if(istype(selling, typepath))
				product_info = wanted_items[typepath]
				typepath_for_product_info = typepath
				break

	if(!product_info)
		return FALSE
	if(product_info[TRADER_PRODUCT_INFO_QUANTITY] <= 0)
		say(return_trader_phrase(TRADER_HAS_ENOUGH_ITEM_PHRASE))
		return FALSE
	cost = apply_sell_price_mods(selling, product_info[TRADER_PRODUCT_INFO_PRICE])
	if(cost <= 0)
		say(return_trader_phrase(ITEM_IS_WORTHLESS_PHRASE))
		return FALSE
	say(return_trader_phrase(INTERESTED_PHRASE))
	say("You will receive [cost] [currency_name] for the [selling].")
	var/list/npc_options = list(
		"Yes" = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_yes"),
		"No" = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_no"),
	)
	face_atom(user)
	var/npc_result = show_radial_menu(user, src, npc_options, custom_check = CALLBACK(src, PROC_REF(check_menu), user), require_near = TRUE, tooltips = TRUE)
	if(npc_result != "Yes")
		say(return_trader_phrase(ITEM_SELLING_CANCELED_PHRASE))
		return TRUE
	say(return_trader_phrase(ITEM_SELLING_ACCEPTED_PHRASE))
	playsound(src, sell_sound, 50, TRUE)
	log_econ("[selling] has been sold to [src] (typepath used for product info; [typepath_for_product_info]) by [user] for [cost] cash.")
	exchange_sold_items(selling, cost, typepath_for_product_info)
	generate_cash(cost, user)
	return TRUE

/**
 * Handles modifying/deleting the items to ensure that a proper amount is converted into cash
 * Arguments:
 * * selling - (Item REF) this is the item being sold
 * * value_exchanged_for - (Number) the "value", useful for a scenario where you want to remove enough items equal to the value
 * * original_typepath - (Typepath) For scenarios where a children of a parent is being sold but we want to modify the parent's product information
 */
/mob/living/simple_animal/hostile/retaliate/trader/ms13/proc/exchange_sold_items(obj/item/selling, value_exchanged_for, original_typepath)
	var/list/product_info = wanted_items[original_typepath]
	if(isstack(selling))
		var/obj/item/stack/the_stack = selling
		var/actually_sold = min(the_stack.amount, product_info[TRADER_PRODUCT_INFO_QUANTITY])
		the_stack.use(actually_sold)
		product_info[TRADER_PRODUCT_INFO_QUANTITY] -= (actually_sold)
	else
		qdel(selling)
		product_info[TRADER_PRODUCT_INFO_QUANTITY] -= 1

/**
 * Modifies the 'base' price of a item based on certain variables
 * Arguments:
 * * selling - Reference to the item being sold
 * * original_cost - the original cost of the item, to be manipulated depending on the variables of the item, one example is using item.amount if it's a stack
 */
/mob/living/simple_animal/hostile/retaliate/trader/ms13/proc/apply_sell_price_mods(obj/item/selling, original_cost)
	if(isstack(selling))
		var/obj/item/stack/stackoverflow = selling
		original_cost *= stackoverflow.amount
	return original_cost

/**
 * Creates an item equal to the value set by the proc and puts it in the user's hands if possible
 * Arguments:
 * * value - The amount of cash that will be created
 * * user - The mob we put the cash in the hands of
 */
/mob/living/simple_animal/hostile/retaliate/trader/ms13/generate_cash(value, mob/user)
	var/obj/item/stack/ms13/currency/dollahs = new accepted_currency(get_turf(user), value)
	user.put_in_hands(dollahs)
