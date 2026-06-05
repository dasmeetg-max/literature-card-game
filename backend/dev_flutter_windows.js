const { exec } = require('child_process');

const roomCode = process.argv[2]?.toUpperCase();

if (!roomCode) {
  console.error("❌ Please provide a room code! Example: node dev_flutter_windows.js ABCD");
  process.exit(1);
}

// Ensure this matches the port you used in the flutter run command!
const flutterPort = 8080;

const bots = [
  { name: "Charles", team: "TEAM RED" },
  { name: "Max", team: "TEAM RED" },
  // { name: "Lewis", team: "TEAM RED" },
  // { name: "George",  team: "TEAM BLUE" },
  { name: "Lando", team: "TEAM BLUE" }
];

console.log(`🚀 Launching Flutter UI windows for room ${roomCode}...`);

bots.forEach((bot, index) => {
  setTimeout(() => {
    const encodedTeam = encodeURIComponent(bot.team);
    const url = `http://localhost:${flutterPort}/?autoJoin=true&name=${bot.name}&room=${roomCode}&team=${encodedTeam}`;

    // 1. Define window size
    const width = 450;
    const height = 800;

    // 2. Grid Calculation
    const windowsPerRow = 3;
    const spacing = 5;
    const xPos = (index % windowsPerRow) * (width + spacing);
    const yPos = Math.floor(index / windowsPerRow) * (height + spacing);

    // 3. The "Force" Flags
    // --user-data-dir is the secret sauce to make size/position flags stick
    const profilePath = `--user-data-dir="${process.cwd()}/bot_profiles/bot_${index}"`;
    const chromeArgs = `--new-window --window-size=${width},${height} --window-position=${xPos},${yPos} ${profilePath} --no-first-run --no-default-browser-check`;

    let command;
    if (process.platform === 'win32') {
      // On Windows, 'start' can sometimes be finicky with quotes; 
      // calling chrome directly is more reliable for flags.
      command = `start chrome ${chromeArgs} "${url}"`;
    } else if (process.platform === 'darwin') {
      command = `open -na "Google Chrome" --args ${chromeArgs} "${url}"`;
    } else {
      command = `google-chrome ${chromeArgs} "${url}"`;
    }

    exec(command, (error) => {
      if (error) console.error(`❌ Failed: ${bot.name}`, error);
      else console.log(`🦋 Launched ${bot.name} at ${width}x${height}`);
    });

  }, index * 2000);
});