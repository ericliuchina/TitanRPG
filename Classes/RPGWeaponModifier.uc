
/*
	FINALLY getting rid of RPGWeapon. This is the future.
*/
class RPGWeaponModifier extends ReplicationInfo abstract
	Config(TitanRPG);

//Weapon
var Weapon Weapon;
var bool bActive;

//Modifier level
var config int MinModifier, MaxModifier;
var bool bCanHaveZeroModifier;

var int Modifier;

//Bonus
var config float DamageBonus, BonusPerLevel;

//Visual
var bool bIdentified;
var Material ModifierOverlay;

//Item name
var localized string PatternPos, PatternNeg;

//AI
var float AIRatingBonus;
var array<class<DamageType> > CountersDamage;
var array<class<RPGWeaponModifier> > CountersModifier;

//Restrictions
var config array<class<Weapon> > ForbiddenWeaponTypes;
var config bool bAllowForSpecials; //inventory groups 0 (super weapons) and 10 (xloc)

//Description
var localized string DamageBonusText;

replication
{
	reliable if(Role == ROLE_Authority && bNetOwner && bNetDirty)
		Weapon, bActive, Modifier, DamageBonus, BonusPerLevel, bIdentified;
	
	reliable if(Role == ROLE_Authority)
		ClientStartEffect, ClientStopEffect, ClientConstructItemName, ClientSetOverlay;
}

static function bool AllowedFor(class<Weapon> WeaponType)
{
	if(!default.bAllowForSpecials &&
		(
			WeaponType.default.InventoryGroup == 0 || //Super weapons
			WeaponType.default.InventoryGroup == 10 || //Translocator
			WeaponType.default.InventoryGroup == 15 //Ball Launcher
		)
	)
	{
		return false;
	}

	return (class'Util'.static.InArray(WeaponType, default.ForbiddenWeaponTypes) == -1);
}

static function RPGWeaponModifier Modify(Weapon W, int Modifier, optional bool bIdentify, optional bool bAdd)
{
	local RPGWeaponModifier WM;
	
	if(!AllowedFor(W.class))
		return None;
	
	if(!bAdd)
	{
		WM = GetFor(W);
		if(WM != None)
			WM.Destroy();
	}
	
	WM = W.Spawn(default.class, W);
	WM.bActive = (W.Instigator.Weapon == W);
	
	if(WM != None)
		WM.SetModifier(Modifier);
	
	if(bIdentify)
		WM.Identify();

	return WM;
}

static function RPGWeaponModifier GetFor(Weapon W)
{
	local RPGWeaponModifier WM;

	if(W != None)
	{
		foreach W.ChildActors(class'RPGWeaponModifier', WM)
			return WM;
	}
	return None;
}

static function string ConstructItemName(class<Weapon> WeaponClass, int Modifier)
{
	local string NewItemName;
	local string Pattern;
	
	if(Modifier >= 0)
		Pattern = default.PatternPos;
	else if(Modifier < 0)
		Pattern = default.PatternNeg;
	
	NewItemName = repl(Pattern, "$W", WeaponClass.default.ItemName);
	
	if(Modifier > 0)
		NewItemName @= "+" $ Modifier;
	else if(Modifier < 0)
		NewItemName @= Modifier;

	return NewItemName;
}

static function int GetRandomModifierLevel()
{
	local int x;

	if(default.MinModifier == 0 && default.MaxModifier == 0)
		return 0;

	x = Rand(default.MaxModifier + 1 - default.MinModifier) + default.MinModifier;
	
	if(x == 0 && !default.bCanHaveZeroModifier)
		x = 1;
		
	return x;
}

function int GetRandomPositiveModifierLevel()
{
	if(MaxModifier == 0)
		return 0;
	else
		return Rand(MaxModifier) + 1;
}

function SetModifier(int x)
{
	local bool bWasActive;
	
	bWasActive = bActive;
	if(bActive)
		SetActive(false);

	Modifier = x;
	
	if(bIdentified)
	{
		Weapon.ItemName = ConstructItemName(Weapon.class, Modifier);
		ClientConstructItemName(Weapon.class, Modifier);
	}
	
	if(bWasActive)
		SetActive(true);
}

simulated function ClientConstructItemName(class<Weapon> SyncWeaponClass, int SyncModifier)
{
	if(Role < ROLE_Authority)
		Weapon.ItemName = ConstructItemName(SyncWeaponClass, SyncModifier);
}

simulated event PostBeginPlay()
{
	Super.PostBeginPlay();
	
	if(Role == ROLE_Authority)
	{
		Weapon = Weapon(Owner);
		if(Weapon == None)
		{
			Warn("Weapon Modifier without a weapon!");
			Destroy();
			return;
		}
		
		Instigator = Weapon.Instigator;
	}
}

simulated event PostNetBeginPlay()
{
	Super.PostNetBeginPlay();
	
	if(Role < ROLE_Authority)
		SetOwner(Weapon);
}

simulated event Tick(float dt)
{
	if(Role == ROLE_Authority)
	{
		if(Weapon == None)
		{
			SetActive(false);
			Destroy();
			return;
		}
		
		if(Instigator != None)
		{
			if(!bActive && Instigator.Weapon == Weapon)
				SetActive(true);
			else if(bActive && Instigator.Weapon != Weapon)
				SetActive(false);
		}
		else if(bActive)
		{
			SetActive(false);
		}
		
		if(bActive)
			RPGTick(dt);
	}
}

function Identify(optional bool bReIdentify)
{
	if(!bIdentified || bReIdentify)
	{
		Weapon.ItemName = ConstructItemName(Weapon.class, Modifier);
		ClientConstructItemName(Weapon.class, Modifier);

		if(bActive)
		{
			SetOverlay();
		
			if(Instigator.Controller.IsA('PlayerController'))
			{
				PlayerController(Instigator.Controller).ReceiveLocalizedMessage(
					class'NewIdentifyMessage', 0,,, Self);
			}
		}

		bIdentified = true;
	}
}

function SetActive(bool bActivate)
{
	if(bActivate && !bActive)
	{
		StartEffect();
		
		if(bIdentified)
			SetOverlay();
		
		ClientStartEffect();
	}
	else if(!bActivate && bActive)
	{
		StopEffect();
		ClientStopEffect();
	}
	
	bActive = bActivate;
}

simulated function SetOverlay()
{
	Weapon.SetOverlayMaterial(ModifierOverlay, 9999, true);

	if(WeaponAttachment(Weapon.ThirdPersonActor) != None)
		Weapon.ThirdPersonActor.SetOverlayMaterial(ModifierOverlay, 999, true);
	
	if(Role == ROLE_Authority)
		ClientSetOverlay();
}

simulated function ClientSetOverlay()
{
	if(Role < ROLE_Authority)
		SetOverlay();
}

//interface
function StartEffect(); //weapon gets drawn
function StopEffect(); //weapon gets put down

simulated function ClientStartEffect();
simulated function ClientStopEffect();

simulated function PostRender(Canvas C); //called client-side by the Interaction

function RPGTick(float dt); //called only if weapon is active

function AdjustTargetDamage(out int Damage, int OriginalDamage, Pawn Injured, vector HitLocation, out vector Momentum, class<DamageType> DamageType)
{
	if(DamageBonus != 0 && Modifier != 0)
		Damage += float(Damage) * Modifier * DamageBonus;
}

function AdjustPlayerDamage(out int Damage, int OriginalDamage, Pawn InstigatedBy, vector HitLocation, out vector Momentum, class<DamageType> DamageType);

function bool PreventDeath(Controller Killer, class<DamageType> DamageType, vector HitLocation, bool bAlreadyPrevented)
{
	return false;
}

function bool AllowEffect(class<RPGEffect> EffectClass, Controller Causer, float Duration, float Modifier)
{
	return true;
}

//TODO: hook into RPGBot
function float GetAIRating()
{
	return Weapon.GetAIRating() * (1.0f + AIRatingBonus);
}

simulated event Destroyed()
{
	SetActive(false);
	
	Super.Destroyed();
}

simulated function string GetDescription()
{
	if(DamageBonus != 0 && Modifier != 0)
		return Repl(DamageBonusText, "$1", GetBonusPercentageString(DamageBonus));
	else
		return "";
}

//Helper function
simulated function string GetBonusPercentageString(float Bonus)
{
	local string text;

	Bonus *= float(Modifier);
	
	if(Bonus > 0)
		text = "+";
	
	Bonus *= 100.0f;
	
	if(float(int(Bonus)) == Bonus)
		text $= int(Bonus);
	else
		text $= Bonus;
	
	text $= "%";
	
	return text;
}

defaultproperties
{
	DamageBonusText="$1 damage"

	DamageBonus=0
	BonusPerLevel=0

	bCanHaveZeroModifier=True
	
	RemoteRole=ROLE_SimulatedProxy
	NetUpdateFrequency=4.00
	bAlwaysRelevant=True
	bOnlyRelevantToOwner=False
	bSkipActorPropertyReplication=True
	bOnlyDirtyReplication=True
	bReplicateMovement=False
	bReplicateInstigator=True
	bMovable=False
	bHidden=True
	
	bAllowForSpecials=True
	
	AIRatingBonus=0
}