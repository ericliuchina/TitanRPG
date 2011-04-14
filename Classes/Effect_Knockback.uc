class Effect_Knockback extends RPGEffect;

var vector Momentum;
var class<DamageType> DamageType;

state Activated
{
	function BeginState()
	{
		Super.BeginState();

		if(
			Instigator.Physics != PHYS_Walking && 
			Instigator.Physics != PHYS_Falling &&
			Instigator.Physics != PHYS_Hovering)
		{
			Instigator.SetPhysics(PHYS_Hovering);
		}
		
		if(VSize(Momentum) > 0)
		{
			Instigator.TakeDamage(
				0,
				EffectCauser.Pawn,
				Instigator.Location,
				Momentum * Modifier * Instigator.Mass,
				DamageType);
		}
	}

	event Tick(float dt)
	{
		Super.Tick(dt);
		
		if(!bPendingDelete)
		{
			if(
				!bAllowOnFlagCarriers &&
				Instigator.PlayerReplicationInfo != None &&
				Instigator.PlayerReplicationInfo.HasFlag != None)
			{
				//exploit fix
				Instigator.Velocity = vect(0, 0, 0);
				Destroy();
				return;
			}
		}
	}
	
	function EndState()
	{
		if(Instigator != None && Instigator.Physics != PHYS_Walking && Instigator.Physics != PHYS_Falling)
			Instigator.SetPhysics(PHYS_Falling);
		
		Super.EndState();
	}
}

defaultproperties
{
	bAllowStacking=False
	bAllowOnFlagCarriers=False

	DamageType=class'fell'
	
	Modifier=1.00

	EffectSound=Sound'WeaponSounds.Misc.ballgun_launch'
	EffectOverlay=Shader'<? echo($packageName); ?>.Overlays.RedShader'
	EffectMessageClass=class'EffectMessage_Knockback'
}