GLOBAL_LIST_INIT(wasteland_positions, list(
	"Wastelander",
	"New Canaanite",
	"Hubologist"))

GLOBAL_LIST_INIT(town_positions, list(
	"Snowcrest Mayor",
	"Snowcrest Citizen",
	"Snowcrest Squatter",
	"Snowcrest Worker",
	"Snowcrest Bartender",
	"Snowcrest Doctor",
	"Snowcrest Nurse",
	"Town Deputy",
	"Snowcrest Bodyguard",
	"Town Sheriff"))

GLOBAL_LIST_INIT(ncr_positions, list(
	"NCR Trooper",
	"NCR Military Police",
	"NCR Radioman",
	"NCR MP Medic",
	"NCR Medic",
	"NCR Engineer",
	"NCR Sergeant",
	"NCR MP Sergeant",
	"NCR Staff Sergeant",
	"NCR Lieutenant"))

/* // There. I made it easy for you to un-fix the server. Just remove the commenting out.
GLOBAL_LIST_INIT(bos_positions, list(
	"BoS Initiate",
	"BoS Knight",
	"BoS Paladin",
	"BoS Head Paladin",
	"BoS Scribe",
	"BoS Head Scribe")) 
*/

GLOBAL_LIST_INIT(raiders_positions, list(
	"Raider",
	"Raider Enforcer",
	"Raider Sawbone",
	"Raider Boss",
	"Slickback Cook",
	"Slickback",
	"Slickback Underboss",
	"Mon City Grunt",
	"Mon City Marksman",
	"Mon City Pointman",
	"Mon City Captain"))

GLOBAL_LIST_INIT(legion_positions, list(
	"Legion Praetorian",
	"Legion Centurion",
	"Legion Veteran Decanus",
	"Legion Prime Decanus",
	"Legion Recruit Decanus",
	"Legion Veteran",
	"Legion Prime ",
	"Legion Recruit",
	"Legion Vexillarius",
	"Legion Speculatore",
	"Legion Explorer",
	"Legion Scout",
	"Legion Blacksmith",))

GLOBAL_LIST_INIT(ranger_positions, list(
	"Desert Ranger Deputy-Chief",
	"Desert Ranger Elite",
	"Desert Ranger",
	"Desert Ranger Sharpshooter",
	"Desert Ranger Doctor",))

GLOBAL_LIST_INIT(drought_town_positions, list(
	"The Baron",
	"Barony Denizen",
	"Barony Laborer",
	"Barony Barkeep",
	"Barony Clinician",
	"Barony Enforcer"))

GLOBAL_LIST_INIT(drylander_positions, list(
	"Drylander Chieftain",
	"Drylander Shaman",
	"Drylander Headtaker",
	"Drylander Hunter",
	"Drylander Folk"))

GLOBAL_LIST_INIT(goldman_positions, list(
	"Goldman Ringleader",
	"Goldman Quartermaster",
	"Goldman Road Runner",
	"Goldman",
	"Goldman Unproven"))

GLOBAL_LIST_INIT(combattest_positions, list(
	"Blue ganger",
	"Red ganger",))

// job categories for rendering the late join menu
GLOBAL_LIST_INIT(ms13_position_categories, list(
	EXP_TYPE_WASTELAND = list("jobs" = wasteland_positions, "color" = "#eec66f"),
	EXP_TYPE_TOWN= list("jobs" = town_positions, "color" = "#4feb64"),
	EXP_TYPE_NCR = list("jobs" = ncr_positions, "color" = "#cfd1ba"),
	//EXP_TYPE_BOS = list("jobs" = bos_positions, "color" = "#737592"),
	EXP_TYPE_RAIDERS = list("jobs" = raiders_positions, "color" = "#30389c"),
	EXP_TYPE_RANGERS = list("jobs" = ranger_positions, "color" = "#bdbc76"),
	EXP_TYPE_DROUGHTTOWN = list("jobs" = drought_town_positions, "color" = "#12491a"),
	EXP_TYPE_DRYLANDERS = list("jobs" = drylander_positions, "color" = "#4e2e04"),
	EXP_TYPE_COMBATTEST = list("jobs" = combattest_positions, "color" = "#4e2e04"),
	EXP_TYPE_GOLDMAN = list("jobs" = goldman_positions, "color" = "#4e2e04")
))

GLOBAL_LIST_INIT(ms13_exp_jobsmap, list(
	EXP_TYPE_WASTELAND = list("titles" = wasteland_positions),
	EXP_TYPE_TOWN = list("titles" = town_positions),
	EXP_TYPE_NCR = list("titles" = ncr_positions),
	//EXP_TYPE_BOS = list("titles" = bos_positions),
	EXP_TYPE_RAIDERS = list("titles" = raiders_positions),
	EXP_TYPE_RANGERS = list("titles" = ranger_positions),
	EXP_TYPE_DROUGHTTOWN = list("titles" = drought_town_positions),
	EXP_TYPE_DRYLANDERS = list("titles" = drylander_positions),
	EXP_TYPE_COMBATTEST = list("titles" = combattest_positions),
	EXP_TYPE_GOLDMAN = list("titles" = goldman_positions)
))

GLOBAL_PROTECT(ms13_exp_jobsmap)

/*
 * Player quality: a self-policing score. Everyone starts at 0. At the end of a round, whoever played rates the others
 * they played with, up or down; a score moves at most one point a round, and only when enough different people agree
 * (MS13_QUALITY_VOTES_NEEDED, and more of them than voted the other way). It's kept with the player's preferences, on
 * the server. Some jobs need a score (GLOB.ms13_quality_job_minimums), and at MS13_QUALITY_OUTCAST or below only one
 * job is open (MS13_QUALITY_OUTCAST_JOB). The jobs and numbers here are placeholders to tune.
 */
#define MS13_QUALITY_MIN -10
#define MS13_QUALITY_MAX 10
#define MS13_QUALITY_VOTES_NEEDED 2
#define MS13_QUALITY_OUTCAST -5
#define MS13_QUALITY_OUTCAST_JOB "Wastelander"

/// Job title -> score needed for it.
GLOBAL_LIST_INIT(ms13_quality_job_minimums, list(
	"BoS Head Paladin" = 1,
	"BoS Head Scribe" = 1,
	"NCR Lieutenant" = 1,
	"Legion Centurion" = 1,
	"Raider Boss" = 1,
	"The Baron" = 1,
	"Snowcrest Mayor" = 1,
	"Town Sheriff" = 1,
	"Desert Ranger Deputy-Chief" = 1,
	"Drylander Chieftain" = 1,
	"Goldman Ringleader" = 1,
))

/// Rated player's ckey -> list(voter's ckey -> 1 or -1), for this round.
GLOBAL_LIST_EMPTY(ms13_quality_votes)
GLOBAL_PROTECT(ms13_quality_votes)
/// Ckey -> "Character (Job)" for everyone who played this round, filled when it ends.
GLOBAL_LIST_EMPTY(ms13_quality_roster)
GLOBAL_PROTECT(ms13_quality_roster)

/datum/preferences
	var/ms13_quality = 0

/datum/preferences/load_preferences()
	. = ..()
	if(savefile)
		ms13_quality = clamp(text2num("[savefile.get_entry("ms13_quality", 0)]") || 0, MS13_QUALITY_MIN, MS13_QUALITY_MAX)

/datum/preferences/save_preferences()
	savefile?.set_entry("ms13_quality", ms13_quality)
	return ..()

/// Whether a player with this score may take this job.
/proc/ms13_quality_allows(score, title)
	if(score <= MS13_QUALITY_OUTCAST)
		return title == MS13_QUALITY_OUTCAST_JOB
	var/minimum = GLOB.ms13_quality_job_minimums[title]
	return isnull(minimum) || score >= minimum

/// How a round's votes on one player move their score: -1, 0 or 1.
/proc/ms13_quality_change(list/votes)
	var/ups = 0
	var/downs = 0
	for(var/voter in votes)
		if(votes[voter] > 0)
			ups++
		else if(votes[voter] < 0)
			downs++
	if(ups >= MS13_QUALITY_VOTES_NEEDED && ups > downs)
		return 1
	if(downs >= MS13_QUALITY_VOTES_NEEDED && downs > ups)
		return -1
	return 0

/datum/controller/subsystem/job/check_job_eligibility(mob/dead/new_player/player, datum/job/possible_job, debug_prefix = "", add_job_to_log = FALSE)
	. = ..()
	if(. == JOB_AVAILABLE && player.client && !ms13_quality_allows(player.client.prefs?.ms13_quality || 0, possible_job.title))
		return JOB_UNAVAILABLE_QUALITY

/// When the round's over, everyone who played gets a ballot on everyone else who did.
/datum/controller/subsystem/ticker/declare_completion()
	. = ..()
	for(var/datum/mind/mind as anything in minds)
		if(mind.key && mind.assigned_role?.title)
			GLOB.ms13_quality_roster[ckey(mind.key)] = "[mind.name] ([mind.assigned_role.title])"
	for(var/voter in GLOB.ms13_quality_roster)
		var/client/voter_client = GLOB.directory[voter]
		if(voter_client && length(GLOB.ms13_quality_roster) > 1)
			ms13_quality_ballot(voter_client.mob)

/// Scores move as the server goes down, once everyone's had their say.
/datum/controller/subsystem/ticker/Shutdown()
	for(var/rated in GLOB.ms13_quality_votes)
		var/change = ms13_quality_change(GLOB.ms13_quality_votes[rated])
		var/datum/preferences/prefs = GLOB.preferences_datums[rated]
		if(!change || !prefs)
			continue
		prefs.ms13_quality = clamp(prefs.ms13_quality + change, MS13_QUALITY_MIN, MS13_QUALITY_MAX)
		prefs.save_preferences()
		log_game("PLAYER QUALITY: [rated] [change > 0 ? "up" : "down"] to [prefs.ms13_quality]")
	return ..()

/// The end-of-round ballot, for someone who played this round.
/proc/ms13_quality_ballot(mob/user)
	var/voter = user?.ckey
	if(!voter || !GLOB.ms13_quality_roster[voter])
		return
	var/list/rows = list("<p>Rate the people you played with this round. It's anonymous: up for good to play with, down for the opposite, or leave it. A player's standing only moves when several people agree, and it opens or shuts some jobs.</p><table>")
	for(var/rated in GLOB.ms13_quality_roster)
		if(rated == voter)
			continue
		var/current = GLOB.ms13_quality_votes[rated]?[voter] || 0
		var/link = "byond://?ms13_rate=[url_encode(rated)]"
		rows += "<tr><td>[html_encode(GLOB.ms13_quality_roster[rated])]</td>\
			<td><a href='[link];vote=1'>[current > 0 ? "<b>Up</b>" : "Up"]</a></td>\
			<td><a href='[link];vote=-1'>[current < 0 ? "<b>Down</b>" : "Down"]</a></td>\
			<td><a href='[link];vote=0'>[current ? "Clear" : ""]</a></td></tr>"
	rows += "</table>"
	var/datum/browser/popup = new(user, "ms13_quality", "This round's players", 460, 520)
	popup.set_content(rows.Join())
	popup.open()

/client/Topic(href, list/href_list, hsrc)
	if(!href_list["ms13_rate"])
		return ..()
	var/rated = href_list["ms13_rate"]
	var/vote = text2num(href_list["vote"])
	if(SSticker.current_state != GAME_STATE_FINISHED || !GLOB.ms13_quality_roster[ckey] || !GLOB.ms13_quality_roster[rated] || rated == ckey || !(vote in list(-1, 0, 1)))
		return
	LAZYINITLIST(GLOB.ms13_quality_votes[rated])
	if(vote)
		GLOB.ms13_quality_votes[rated][ckey] = vote
	else
		GLOB.ms13_quality_votes[rated] -= ckey
	ms13_quality_ballot(mob)

/client/verb/ms13_rate_players()
	set name = "Rate Players"
	set category = "OOC"
	if(SSticker.current_state != GAME_STATE_FINISHED || !GLOB.ms13_quality_roster[ckey])
		to_chat(src, span_warning("You can rate the people you played with once the round's over."))
		return
	ms13_quality_ballot(mob)

/world/AVerbsAdmin()
	. = ..()
	. += /client/proc/ms13_set_quality

/client/proc/ms13_set_quality()
	set name = "Set Player Quality"
	set category = "Admin"
	if(!check_rights(R_ADMIN))
		return
	var/target = ckey(input(src, "Whose player quality? (ckey)", "Player quality") as text|null)
	var/datum/preferences/prefs = GLOB.preferences_datums[target]
	if(!prefs)
		to_chat(src, span_warning("No preferences loaded for [target]; they need to have connected this round."))
		return
	var/score = input(src, "[target] is at [prefs.ms13_quality] ([MS13_QUALITY_MIN] to [MS13_QUALITY_MAX]). Set it to:", "Player quality", prefs.ms13_quality) as num|null
	if(isnull(score))
		return
	prefs.ms13_quality = clamp(round(score), MS13_QUALITY_MIN, MS13_QUALITY_MAX)
	prefs.save_preferences()
	log_admin("[key_name(src)] set [target]'s player quality to [prefs.ms13_quality].")
	message_admins("[key_name_admin(src)] set [target]'s player quality to [prefs.ms13_quality].")

#ifdef UNIT_TESTS
/datum/unit_test/ms13_player_quality
	name = "JOBS: Player Quality Gates Jobs And Moves On Agreement"

/datum/unit_test/ms13_player_quality/Run()
	for(var/score in MS13_QUALITY_MIN to MS13_QUALITY_MAX)
		if(!ms13_quality_allows(score, MS13_QUALITY_OUTCAST_JOB))
			return Fail("Score [score] blocks the fallback job.")
		if(ms13_quality_allows(score, "NCR Trooper") != (score > MS13_QUALITY_OUTCAST))
			return Fail("Score [score] applies the wrong restriction to an ordinary job.")
	if(ms13_quality_change(list("a" = 1)) != 0)
		return Fail("One vote moved a score.")
	if(ms13_quality_change(list("a" = 1, "b" = 1)) != 1 || ms13_quality_change(list("a" = -1, "b" = -1, "c" = 1)) != -1)
		return Fail("Agreeing votes didn't move a score one point.")
	if(ms13_quality_change(list("a" = 1, "b" = 1, "c" = -1, "d" = -1)) != 0)
		return Fail("A split vote moved a score.")
	if(!ms13_quality_allows(0, "Wastelander") || ms13_quality_allows(0, "The Baron") || !ms13_quality_allows(1, "The Baron"))
		return Fail("Job minimums aren't applied.")
	if(ms13_quality_allows(MS13_QUALITY_OUTCAST, "NCR Trooper") || !ms13_quality_allows(MS13_QUALITY_OUTCAST, MS13_QUALITY_OUTCAST_JOB))
		return Fail("An outcast could take something other than [MS13_QUALITY_OUTCAST_JOB], or not that.")
#endif
