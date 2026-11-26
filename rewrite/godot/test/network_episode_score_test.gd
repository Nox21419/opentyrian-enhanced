extends "res://test/network_episode_hint_test.gd"

const Score := preload("res://scripts/network_episode_score.gd")


func test_native_score_envelopes_preserve_script_and_reject_unowned_autosave_or_overflow() -> void:
	for ep in range(1, 6):
		var source := _ending_context(ep)
		var script := Score.build(source[0], source[1], source[2], source[3], SESSION)
		assert_bool(Score.valid_script(script)).is_true()
		assert_int(script.screens.size()).is_equal(source[2].script.screens.size() + 1)
		assert_bool(script.screens.slice(0, -1) == source[2].script.screens).is_true()
		assert_str(source[2].script.stop).is_equal("episode_end")
		assert_str(script.stop).is_equal("shop")
		assert_array(script.episode_score.cash).is_equal(["ffffffffffffffff", "8000000000000000"])
		(
			assert_bool(
				script.screens.back().text == Hint.build(source[0], source[1], source[2], source[3], SESSION).text
			)
			. is_true()
		)
		assert_dict(Next.build(source[0], source[2], "1234567890abcdef")).is_empty()
	var source := _ending_context(1)
	source[2].script.autosave = true
	source[2].digest = Cursor.proposal_digest(source[2])
	assert_dict(Score.build(source[0], source[1], source[2], source[3], SESSION)).is_empty()
	source[2].script.autosave = false
	source[2].script.screens.clear()
	for i in 128:
		source[2].script.screens.append({"directive": "]M", "text": PackedStringArray()})
	source[2].digest = Cursor.proposal_digest(source[2])
	assert_dict(Score.build(source[0], source[1], source[2], source[3], SESSION)).is_empty()
