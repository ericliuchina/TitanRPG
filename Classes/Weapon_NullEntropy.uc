class Weapon_NullEntropy extends RPGWeapon
	HideDropDown
	CacheExempt;
	
var localized string NullEntropyText;

function RPGAdjustTargetDamage(out int Damage, int OriginalDamage, Pawn Victim, vector HitLocation, out vector Momentum, class<DamageType> DamageType)
{
	local RPGEffect Effect;

	Super.RPGAdjustTargetDamage(Damage, OriginalDamage, Victim, HitLocation, Momentum, DamageType);
	
	if(Damage > 0)
	{
		Effect = class'Effect_NullEntropy'.static.Create(
			Victim,
			Instigator.Controller,
			FMax(1.0f, BonusPerLevel * float(Modifier)));
			
		if(Effect != None)
		{
			Momentum = vect(0, 0, 0);
			Effect.Start();
			Identify();
		}
	}
}

simulated function string GetWeaponNameExtra()
{
	local string text;
	
	text = Super.GetWeaponNameExtra();
	
	if(text != "")
		text $= ", ";
	
	text $= NullEntropyText;
	
	return text;
}

defaultproperties
{
	//bAddToOldWeapons=False
	NullEntropyText="immobilizes human targets"
	DamageBonus=0.050000
	BonusPerLevel=0.333333
	MinModifier=3
	MaxModifier=6
	ModifierOverlay=Shader'MutantSkins.Shaders.MutantGlowShader'
	PatternPos="Null Entropy $W"
	//AI
	AIRatingBonus=0.075000
}