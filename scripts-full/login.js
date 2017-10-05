// Copyright (C) 2017-Present Pivotal Software, Inc. All rights reserved.
// This program and the accompanying materials are made available under
// the terms of the under the Apache License, Version 2.0 (the "License”);
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

(function() {
'use strict';

ObjC.import('stdlib');

var sys = Application('System Events');
var chrome = Application('com.google.Chrome');

var user_email = $.getenv('USER_EMAIL');
var mfa_mode = $.getenv('MFA_MODE');

// Passwords are obfuscated when sent to the browser so that they won't be trivial to read if
// it ever messes up and prints them in an error or similar
function obfuscate_and_escape(s) {
	var r = '';
	for(var i = 0; i < s.length; i ++) {
		var u = (s.charCodeAt(i) + 1234 + i * 100) % 65536;
		var seq = u.toString(16);
		r += '\\u' + '0000'.substr(seq.length) + seq;
	}
	return r;
}

function deobfuscate(s) {
	var r = '';
	for(var i = 0; i < s.length; i ++) {
		r += String.fromCharCode((((s.charCodeAt(i) - 1234 - i * 100) % 65536) + 65536) % 65536);
	}
	return r;
}

function run_until_success(fnc, repeat_delay) {
	while(true) {
		var result = fnc();
		if(result) {
			return result;
		}
		delay(repeat_delay || 0.1);
	}
}

function wait_until(condition) {
	run_until_success(condition, 0.01);
}

function make_active(app) {
	if(!app.frontmost()) {
		app.activate();
		// Wait for activation
		wait_until(() => app.frontmost());
	}
}

function type_message(msg) {
	for(var i = 0; i < msg.length; i ++) {
		if(msg[i] == '\n') {
			sys.keyCode(36);
		} else {
			sys.keystroke(msg[i]);
		}
		// Work around a keystroke bug in some versions of OSX by sending keys with
		// a small delay. Prevents random upper-caseing of letters in output
		delay(0.01);
	}
}

function escape_single(v) {
	return v
		.replace(/\\/g, '\\\\')
		.replace(/\r/g, '\\\r')
		.replace(/\n/g, '\\\n')
		.replace(/'/g, '\\\'');
}

function runjs(app, tab, code) {
	return app.execute(tab, {'javascript': '(function(){' + code + '}());'});
}

// Doesn't work - permissions issue :(
//function runjs_inside_webview(app, tab, wvid, code) {
// 	// executeScript is asynchronous, so we can't get return values unless we poll;
// 	// just check whether the webview itself was found, though the content may still be loading
// 	return runjs_until_success(app, tab,
// 		"var w = document.getElementById('" + escape_single(wvid) + "');" +
// 		"if(!w || !w.executeScript) {" +
// 		"	return false;" +
// 		"}" +
// 		"w.executeScript({'code': '" + escape_single(code) + "'});" +
// 		"return true;"
// 	);
//}

function runjs_inside_webview_hack(app, tab, wvid, code) {
	// Send the code directly so we don't risk typing passwords in the wrong place
	runjs(app, tab, "document.getElementById('signin-frame').dataset.c='" + escape_single(code) + "';");

	// Now manually write the invocation code in the developer console, since we don't have permission to run it ourselves
	// (requires application focus and tab focus)
	make_active(app);

	// Open developer console
	sys.keystroke('j', {'using': ['command down', 'option down']});
	delay(2); // Wait for ready

	// Keep this code short for speed and ensure it never has any sensitive info!
	type_message(
		"var o=document.getElementById('signin-frame');" +
		"o.executeScript({code:o.dataset.c})" +
		"\n" // execute
	);

	// Close developer console
	sys.keystroke('j', {'using': ['command down', 'option down']});
	delay(0.5); // Wait for console to disappear

	// Remove sensitive code ASAP
	runjs(app, tab, "document.getElementById('signin-frame').dataset.c='';");
}

function find_window(app, id) {
	for(var i = 0; i < app.windows.length; i ++) {
		if(app.windows[i].id() == id) {
			return app.windows[i];
		}
	}
	return null;
}

// Open Chrome if not running
if(!sys.processes[chrome.name()]) {
	chrome.launch();
}

var stage = 0;
var current_window_id;
var profile_login_tab;
var not_okta = '';

if(stage < 1) {
	console.log("Stage 1: Add Profile");
	// Press menu item: People -> Add Person...
	// TODO: this part requires Assistive access. None of the rest does; would be nice to avoid here too

	make_active(chrome); // Need menu bar access

	var old_win_id = null;
	var close_old_win = false;
	if(chrome.windows.length >= 1) {
		var win = chrome.windows[0];
		old_win_id = win.id();
		// Launching Chrome opens a blank window; detect this and close it later
		if(win.tabs.length === 1 && win.tabs[0].title() === 'New Tab') {
			close_old_win = true;
		}
	}

	var add_person = sys.processes[chrome.name()].menuBars[0]
		.menuBarItems['People'].menus[0]
		.menuItems['Add Person\u2026'];

	if(!add_person.enabled()) {
		// Add Person is disabled in guest window; switch to a random standard profile first
		sys.click(sys.processes[chrome.name()].menuBars[0]
			.menuBarItems['People'].menus[0]
			.menuItems[0]);

		wait_until(() => add_person.enabled());

		if(old_win_id !== null) {
			wait_until(() => (chrome.windows[0].id() != old_win_id));
		}

		// Close the original guest window if it isn't actually being used
		if(close_old_win) {
			var win = find_window(chrome, old_win_id);
			if(win !== null) {
				chrome.close(win);
			}
			close_old_win = false;
		}

		// If we opened a new window, close this random person's window when ready
		var win = chrome.windows[0];
		old_win_id = win.id();
		if(win.tabs.length === 1 && win.tabs[0].title() === 'New Tab') {
			close_old_win = true;
		}
	}

	sys.click(add_person);

	// Wait for new profile window to open
	if(old_win_id !== null) {
		wait_until(() => (chrome.windows[0].id() != old_win_id));
	} else {
		wait_until(() => (chrome.windows.length >= 1));
	}
	current_window_id = chrome.windows[0].id();
	profile_login_tab = chrome.windows[0].activeTab();

	if(close_old_win) {
		var win = find_window(chrome, old_win_id);
		if(win !== null) {
			chrome.close(win);
		}
		close_old_win = false;
	}

	// Detect where we've ended up
	stage = run_until_success(() => runjs(chrome, profile_login_tab,
		"if(document.getElementById('signin-frame')) {" +
		"	return 4;" +
		"}" +
		"if(document.getElementById('accept-button')) {" +
		"	return 1;" +
		"}" +
		"return 0;"
	));
} else {
	current_window_id = chrome.windows[0].id();
	profile_login_tab = chrome.windows[0].activeTab();
}

if(stage < 2) {
	console.log("Stage 2: Sign in button");
	delay(0.5); // Wait for handlers to be added. TODO: poll somehow (waiting for DOMContentLoad doesn't seem to be enough)
	runjs(chrome, profile_login_tab, "document.getElementById('accept-button').click();");
	stage = 2;
}

if(stage < 3) {
	console.log("Stage 3: Sign in popup");

	delay(3); // Wait for popup to appear & load. TODO: poll somehow
	make_active(chrome); // Need keyboard access
	type_message(user_email + '\n');
	stage = 3;
}

if(stage < 4) {
	console.log("Stage 4a: Wait for Google auth page (if a CAPTCHA appears, manual action is required!)");
	// Wait for popup to disappear
	// (might be a long time; Google might have decided to make us solve a CAPTCHA)
	run_until_success(() => {
		profile_login_tab = find_window(chrome, current_window_id).activeTab();
		return runjs(chrome, profile_login_tab, "return !!document.getElementById('signin-frame');");
	});

	console.log("Stage 4b: Wait for Google auth page to load");
	wait_until(() => !profile_login_tab.loading());
	delay(2); // Wait for inner page to load (TODO: is there a way to check?)
	stage = 4;
}

if(stage < 5) {
	console.log("Stage 5: Google auth page");

	// Store the current login URL so that we can detect once we've moved on to Okta later
	not_okta = runjs(chrome, profile_login_tab, "return document.getElementById('signin-frame').getAttribute('src');");

	// Auth page lives inside WebView which blocks access :(
	make_active(chrome); // Need keyboard access
	type_message(user_email + '\n');

	// Alternative which would be nicer if it worked
	//runjs_inside_webview(chrome, login_tab, 'signin-frame',
	//	"var o = document.getElementById('Email');" +
	//	"o.value='" + escape_single(user_email) + "';" +
	//	"o.form.submit();"
	//);
	stage = 5;
}

if(stage < 6) {
	console.log("Stage 6a: Wait for Okta auth page");

	// Wait for Okta login page to appear
	run_until_success(() => {
		var url = runjs(chrome, profile_login_tab, "return document.getElementById('signin-frame').getAttribute('src');");
		return url != '' && url != not_okta;
	});

	console.log("Stage 6b: Wait for Okta auth page to load");
	wait_until(() => !profile_login_tab.loading());
	delay(2); // Wait for inner page to load (TODO: is there a way to check?)
	delay(0.3); // Wait for animation
	stage = 6;
}

if(stage < 7) {
	console.log("Stage 7: Okta auth page");

	// Okta login page
	type_message(user_email);
	type_message('\t'); // tab
	if(/^(59|60)\./.test(chrome.version())) {
		// https://github.com/pivotal/usb-login-scripts/issues/11
		// https://bugs.chromium.org/p/chromium/issues/detail?id=661810

		// Chrome 59 and 60 broke this behaviour, but 61 fixed it.

		console.log("! Old Chrome version detected: automatic secure password entry not available (manual action required!)");
	} else {
		runjs_inside_webview_hack(chrome, profile_login_tab, 'signin-frame',
			"var deobfuscate = " + deobfuscate.toString() + ";" +
			"var p=document.getElementsByName('password')[0];" +
			"if(p.getAttribute('type') == 'password') {" + // safety
			"	p.value=deobfuscate('" + obfuscate_and_escape($.getenv('USER_PASSWORD')) + "');" +
			// Do everything we can to tell Okta that we changed the password
			"	p.dispatchEvent(new KeyboardEvent('keydown', {bubbles : true, cancelable : true}));" +
			"	p.dispatchEvent(new KeyboardEvent('keypress', {bubbles : true, cancelable : true}));" +
			"	p.dispatchEvent(new InputEvent('textInput', {bubbles : true, cancelable : true}));" +
			"	p.dispatchEvent(new InputEvent('input', {bubbles : true, cancelable : true}));" +
			"	p.dispatchEvent(new KeyboardEvent('keyup', {bubbles : true, cancelable : true}));" +
			"	p.dispatchEvent(new Event('change', {bubbles : true, cancelable : true}));" +
			"	p.blur();" +
			"}"
		);
		type_message('\n');
	}
	stage = 7;
}

// TODO: we could be our own MFA device (generating the unique code using the published algorithm),
// but since the memory stick isn't secure, this is rather risky. Ideally we would combine the
// memory stick with a secure USB-based 2FA device. For now, just get the human to do it for us.
// The 2 message boxes which appear after logging in do not seem to be keyboard accessible,
// so there's not much we can do about them either. This check will wait for both to complete.
if(stage < 8) {
	console.log("Stage 8: Okta 2FA (manual action required!)");

	if(mfa_mode === 'push') {
		// TODO: press button to push to device
	} else if(mfa_mode === 'app') {
		// TODO: press button to enter code
	}

	// Wait for login pages to disappear
	run_until_success(() => {
		try {
			return (
				find_window(chrome, current_window_id).activeTab().id() != profile_login_tab.id() ||
				runjs(chrome, profile_login_tab, "return !document.getElementById('signin-frame');")
			);
		} catch(e) {
			return false; // tab probably closed while we were checking it; next loop will confirm
		}
	});
	stage = 8;
}

if(stage < 9) {
	console.log("Stage 9a: Open Okta launchpad");
	// Wait for auth tab to close
	while(find_window(chrome, current_window_id).tabs.length > 1) {
		chrome.close(find_window(chrome, current_window_id).tabs[1]);
		delay(0.1);
	}
	profile_login_tab = find_window(chrome, current_window_id).activeTab();

	profile_login_tab.url = 'https://pivotal.okta.com';

	console.log("Stage 9b: Wait for Okta launchpad to load");
	wait_until(() => !profile_login_tab.loading());
	run_until_success(() => runjs(chrome, profile_login_tab, "return !!document.getElementsByName('username')[0];"));
	stage = 9;
}

if(stage < 10) {
	console.log("Stage 10: Sign in to Okta launchpad");
	// Don't need to hack it this time; we're not in layers of frames
	runjs(chrome, profile_login_tab,
		"var n=document.getElementsByName('username')[0];" +
		"n.value='" + escape_single(user_email) + "';" +
		"n.dispatchEvent(new KeyboardEvent('keydown', {bubbles : true, cancelable : true}));" +
		"n.dispatchEvent(new KeyboardEvent('keypress', {bubbles : true, cancelable : true}));" +
		"n.dispatchEvent(new InputEvent('textInput', {bubbles : true, cancelable : true}));" +
		"n.dispatchEvent(new InputEvent('input', {bubbles : true, cancelable : true}));" +
		"n.dispatchEvent(new KeyboardEvent('keyup', {bubbles : true, cancelable : true}));" +
		"n.dispatchEvent(new Event('change', {bubbles : true, cancelable : true}));" +
		"n.blur();" +
		"return true;"
	);
	delay(0.1); // Give Okta a moment to realise we entered a username
	runjs(chrome, profile_login_tab,
		"var deobfuscate = " + deobfuscate.toString() + ";" +
		"var p=document.getElementsByName('password')[0];" +
		"if(p.getAttribute('type') != 'password') {" + // safety
		"	return false;" +
		"}" +
		"p.value=deobfuscate('" + obfuscate_and_escape($.getenv('USER_PASSWORD')) + "');" +
		// Do everything we can to tell Okta that we changed the password
		"p.dispatchEvent(new KeyboardEvent('keydown', {bubbles : true, cancelable : true}));" +
		"p.dispatchEvent(new KeyboardEvent('keypress', {bubbles : true, cancelable : true}));" +
		"p.dispatchEvent(new InputEvent('textInput', {bubbles : true, cancelable : true}));" +
		"p.dispatchEvent(new InputEvent('input', {bubbles : true, cancelable : true}));" +
		"p.dispatchEvent(new KeyboardEvent('keyup', {bubbles : true, cancelable : true}));" +
		"p.dispatchEvent(new Event('change', {bubbles : true, cancelable : true}));" +
		"p.blur();" +
		"return true;"
	);
	delay(0.1); // Give Okta a moment to realise we entered a password
	runjs(chrome, profile_login_tab,
		"document.getElementsByClassName('button-primary')[0].click();"
	);
	stage = 10;
}

if(stage < 11) {
	console.log("Stage 11: Okta 2FA (manual action required!)");
	if(mfa_mode === 'push') {
		// TODO: press button to push to device
	} else if(mfa_mode === 'app') {
		// TODO: press button to enter code
	}
	// No need to wait; we're done. Might as well let the script unmount the drive while the user does 2FA.
	stage = 11;
}

console.log("Done");

}());
