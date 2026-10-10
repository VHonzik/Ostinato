# Big pivot

As we are nearing the end of planned work for demo, play-testing revealed major issue of the main game loop not being necessarily that fun. So I have decided to perform a big pivot for the project with wide-reaching implications.

## Retrospective

First my two cents about the project so far.

### What went right

- Milestones are great for splitting up the work. We managed to keep them with reasonable scope.
- The core roguelike experience is solid. Movement and combat is well done. It feels close to Caves of Qud which was desired.
- The keyboard heavy controls are enjoyable. It might not be for everyone but with enough quality of life features, there is very little need for mouse.
- QA instructions on PRs are great and easy to follow.

### What could be improved

- While inventory, gold, looting, skill trainers and traders work well, due to the nature of the game being a loop, these systems quickly lose their attractiveness.
- Combination of requirements and milestones helps with project focus but we will need to analyze it a bit. Milestones should be separated from requirements and we should consider scrapping formal requirements. They are too rigid for this project and what we actually need is granular tasks.
- Unit tests are great but our strict validation rules cost a lot of tokens. We need to de-emphasize validation in favor of QA and play-testing. Also performing full validation on everything is again token expensive.
- I would like to move away from tight github integration that was gradually introduced. While milestones and PRs look great when look from outside there is also cost associated, especially AI tokens. We will likely perform reviews and QA offline.
- We need to evaluate the AI model usage. I have been mostly using Astra High just for fun and the quality is great but the token usage is likely too high for our needs. I would like to perform controller trial on future tasks.
- Stalker(s) will be a great obstacle and end of the demo. However currently I am not sure they are even possible to defeat due to level difference and second stalker comes way to soon as well. Fighting stalker is not fun due to resists and misses.
- The art style will work but we need to focus on it more. There are some serious readability issues right now.

### What went wrong

- Focus on caster was a bad call. I have assumed there will be a lot of synergies between caster spells and they share mana as resource. I also liked the fantasy of powerful archmage with many different schools of magic. However the synergies come online on higher levels or with talents if at all. Their toolkit is also largely overlapping so learning shadowbolt in addition to fireball brings almost no power gain. Targeted casting is also annoying control wise.
- Strict rules for only referencing Vanilla WoW are costing us a lot of AI tokens. It also makes classes boring and leveling grindy. The idea was to preserve the spirit of WoW Vanilla but we have mostly preserved the tedium. We also spend too much time on researching topics and being 100% accurate which is not only unnecessary but also detrimental to the project enjoyment.
- Really small resolution is a major bottle-neck now. UI is cluttered and the actual game is around one third of the screen space.
- Lack of focus on art and world is diminishing my enjoyment for the project.
- Too much documentation. This is hobby game not a serious SW engineering project. We don't need reports at all. Each milestones generates tons of documentation for very little gain. Related to strict Vanilla adherence and requirements we generated a lot of data documentation. The game itself should hold all the data and design we don't need external documents for it.
- Too many NPCs. The world is bursting at its seems with NPCs that also lack and distinct features.
- Slow leveling. It takes ages to level and I am not sure it's even possible to get to level 10 through normals means.

## The big pivot actions

### Art overhaul

We will design the world and create a list of all sprites that the demo will need. I will than create a spritesheet that might not be a final but it will carry us through the demo. We will double the resolution while keeping roughly of how much player sees and how big sprites are. We will focus on UI as well, the combat log needs to be less prominent, we will much more spaces in hotbar and we designated menu for all other player menus.

### Let's show meelees some love

We 180 caster focus. Warrior will be a new starting class. We will add rogue but only combo points mechanic, rage will become new primary resource. Poisons and slice and dice are the main draw. We will keep shaman for fun mechanics like windfury, flurry, shields. We will keep paladin for seals, possibly judgements and powerful buffs. We will remove all other classes. We will play with the melee attack mechanic since melee attacks will no be semi-automic and core gameplay feature.

### Vanilla is too plain

We will no longer adhere to Vanilla, period. We will keep thinking about spirit of WoW and Vanilla but there will be no binding contract to stick to it. This means rework of XPs, NPCs, classes, world and just about everything. We will only stick roughly with human 1-10 opening. We will also put emphasis on story more. Loops should open up new dialogues and player should realize they are in a loop while the NPCs have no clue. The NPCs knowledge of the invasion will be severely cut. We will remove NPC respawns, reduce their numbers and tailor XP rewards to ensure average player takes something like 10 minutes of gameplay to finish first loop (subject to balancing) and die to stalker :)

### Classes progression

We will overhaul spells, ranks and class trainers. Player will still unlock classes through initial dialogue but with more story. Class will now have a distinct progression track with both active and passive abilities that will be leveled by using the class abilities. Once next checkpoint is reached player still needs to visit class trainer. The progression of course stick through loop. We will move signature class abilities early to the progression and we will be picky about skills we will put on the progression track. They will have represent the class identit well.

### Cut the fat

We will deep dive the documentation, validation and the project set-up and cut all the fat. We experiment with AI models and try to minimize token usage without sacrificing quality. We will no longer treat this project that serious and we will rely more on prompting the human operator for decision making on the spot.

## Immediate actions

I would like to start with the project structure, planning documentation and validation. Can you do a deep dive while keeping the retrospective in mind and suggest changes. Please do so iteratively and grill me on any decision. Be aggressive with deleting and reworking. Nothing is sacred at the moment. Be pro-active in suggesting new processes. Regular development rules and Agents.MD instructions don't necessarily apply right now since we are reworking the repo. The outcome should be a discussion with the operator, leading to sweeping changes that I will than manually commit.

