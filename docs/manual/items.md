---
layout: default
title: Items
permalink: /manual/items/
---

# Items

Everything that is not a whip, knife, axe, cross, or holy-water vial. Weapons live on [their own page]({{ '/manual/weapons/' | relative_url }}). Seconds assume 60 frames a second. Percents are of Simon's full life bar (32 points).

<div class="entry">
{% include portrait.html kind="items" slug="small-heart" name="Small heart" %}
<div class="body">

## Small heart {#small-heart}

+1 heart. Currency, not health. Whip a candle.

<audio controls src="{{ '/manual/assets/audio/0F_heart.wav' | relative_url }}"></audio>

</div>
</div>

<div class="entry">
{% include portrait.html kind="items" slug="large-heart" name="Large heart" %}
<div class="body">

## Large heart {#large-heart}

+5 hearts.

<audio controls src="{{ '/manual/assets/audio/0F_heart.wav' | relative_url }}"></audio>

</div>
</div>

<div class="entry">
{% include portrait.html kind="items" slug="small-orb" name="Life orb" %}
<div class="body">

## Life orb {#small-orb}

+25% life (8 of 32). Not a heart.

</div>
</div>

<div class="entry">
{% include portrait.html kind="items" slug="potion" name="Potion" %}
<div class="body">

## Potion {#potion}

Fills the bar (+100%). Vendors sell it. The orb that falls after a boss is a different object with the same courtesy.

</div>
</div>

<div class="entry">
{% include portrait.html kind="items" slug="red-shield" name="Red shield" %}
<div class="body">

## Red shield {#red-shield}

Face the hit and contact damage is not doubled — you take the table value instead. 16 charges, then it drops. You cannot wear this and the yellow shield at once.

</div>
</div>

<div class="entry">
{% include portrait.html kind="items" slug="yellow-shield" name="Yellow shield" %}
<div class="body">

## Yellow shield {#yellow-shield}

Eats enemy shots. Same 16 charges, same exclusivity with the red one.

</div>
</div>

<div class="entry">
{% include portrait.html kind="items" slug="white-cross" name="White cross" %}
<div class="body">

## White cross {#white-cross}

Clears the screen. Instant. Does not linger.

<audio controls src="{{ '/manual/assets/audio/1B_white_cross.wav' | relative_url }}"></audio>

</div>
</div>

<div class="entry">
{% include portrait.html kind="items" slug="rosary" name="Rosary" %}
<div class="body">

## Rosary {#rosary}

Stops **new** enemies from walking in for **2.5 seconds** (4.0 s if you have the [tipped hourglass](#tipped-hourglass)). Whatever is already on screen keeps moving.

</div>
</div>

<div class="entry">
{% include portrait.html kind="items" slug="blue-gem" name="Blue gem" %}
<div class="body">

## Blue gem {#blue-gem}

Invisibility. Simon flashes white. **2.5 s** (4.0 s tipped). You still have to watch the floor.

<audio controls src="{{ '/manual/assets/audio/16_blue_gem.wav' | relative_url }}"></audio>

</div>
</div>

<div class="entry">
{% include portrait.html kind="items" slug="sapphire-ring" name="Sapphire ring" %}
<div class="body">

## Sapphire ring {#sapphire-ring}

Touch-kills. Simon flashes red. **2.5 s** (4.0 s tipped).

</div>
</div>

<div class="entry">
{% include portrait.html kind="items" slug="hourglass" name="Hourglass" %}
<div class="body">

## Hourglass {#hourglass}

Jump, tap down, spend **five hearts**. Enemies freeze for **1.5 s** (2.5 s tipped). You have to be in the air; crouching on the floor does nothing.

</div>
</div>

<div class="entry">
{% include portrait.html kind="items" slug="tipped-hourglass" name="Tipped hourglass" %}
<div class="body">

## Tipped hourglass {#tipped-hourglass}

Whip a world hourglass **once** before you take it. The picture tips on its side. Collecting that form does **not** give you freeze — it makes rosary, gem, ring, and freeze last longer, until you die. Whip it a second time and the pickup vanishes.

Buying the hourglass from a vendor is instant; there is nothing to whip.

</div>
</div>

<div class="entry">
{% include portrait.html kind="items" slug="boots" name="Boots" %}
<div class="body">

## Boots {#boots}

Faster walk. Lost on death.

</div>
</div>

<div class="entry">
{% include portrait.html kind="items" slug="wings" name="Wings" %}
<div class="body">

## Wings {#wings}

Higher jump. Lost on death.

</div>
</div>

<div class="entry">
{% include portrait.html kind="items" slug="candle" name="Candle" %}
<div class="body">

## Candle {#candle}

White outlines on breakable blocks, so the fake walls stop hiding.

</div>
</div>

<div class="entry">
{% include portrait.html kind="items" slug="map" name="Map" %}
<div class="body">

## Map {#map}

F2, three looks. The in-game map is a schematic, not the annotated one in this handbook. Death does not take it.

</div>
</div>

<div class="entry">
{% include portrait.html kind="items" slug="black-bible" name="Black bible" %}
<div class="body">

## Black bible {#black-bible}

Vendor prices **double**. Drops the white bible if you were holding it.

</div>
</div>

<div class="entry">
{% include portrait.html kind="items" slug="white-bible" name="White bible" %}
<div class="body">

## White bible {#white-bible}

Vendor prices **halve** (see the [price table]({{ '/manual/vendors/' | relative_url }})). Drops the black bible.

</div>
</div>

<div class="entry">
{% include portrait.html kind="items" slug="lockpick" name="Lockpick" %}
<div class="body">

## Lockpick {#lockpick}

Opens **three** chests. You drop the yellow key if you were holding one.

<audio controls src="{{ '/manual/assets/audio/0F_heart.wav' | relative_url }}"></audio>

</div>
</div>

<div class="entry">
{% include portrait.html kind="items" slug="yellow-key" name="Yellow key" %}
<div class="body">

## Yellow key {#yellow-key}

Opens **one** chest. One at a time.

<audio controls src="{{ '/manual/assets/audio/14_key.wav' | relative_url }}"></audio>

</div>
</div>

<div class="entry">
{% include portrait.html kind="items" slug="white-key" name="White key" %}
<div class="body">

## White key {#white-key}

Opens that stage's door. Hidden on purpose. Spent when you walk through.

<audio controls src="{{ '/manual/assets/audio/14_key.wav' | relative_url }}"></audio>

</div>
</div>

<div class="entry">
{% include portrait.html kind="items" slug="chest" name="Chest" %}
<div class="body">

## Chest {#chest}

Needs the yellow key or a lockpick charge. The reward is whatever was packed inside — hearts, gear, a bag of points.

<audio controls src="{{ '/manual/assets/audio/11_chest.wav' | relative_url }}"></audio>

</div>
</div>

<div class="entry">
{% include portrait.html kind="items" slug="white-bag" name="White money bag" %}
<div class="body">

## White money bag {#white-bag}

+5,000 points.

<audio controls src="{{ '/manual/assets/audio/10_money_bag.wav' | relative_url }}"></audio>

</div>
</div>

<div class="entry">
{% include portrait.html kind="items" slug="blue-bag" name="Blue money bag" %}
<div class="body">

## Blue money bag {#blue-bag}

+1,000 points.

<audio controls src="{{ '/manual/assets/audio/10_money_bag.wav' | relative_url }}"></audio>

</div>
</div>

<div class="entry">
{% include portrait.html kind="items" slug="slime" name="Slime" %}
<div class="body">

## Slime {#slime}

Looks like a candle drop. Catching it does nothing. Leave it on the floor and it hatches a blob — blue, white, or red depending how far into the castle you are. See the [bestiary]({{ '/manual/bestiary/#blob-blue' | relative_url }}).

</div>
</div>
