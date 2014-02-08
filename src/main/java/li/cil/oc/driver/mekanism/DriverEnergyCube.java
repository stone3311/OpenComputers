package li.cil.oc.driver.mekanism;


import dan200.computer.api.IPeripheral;
import li.cil.oc.api.network.ManagedEnvironment;
import li.cil.oc.api.prefab.ManagedPeripheral;
import li.cil.oc.driver.computercraft.DriverPeripheral;
import li.cil.oc.util.Reflection;
import net.minecraft.world.World;

public class DriverEnergyCube extends DriverPeripheral {
    private static final Class<?> TileentityEnergyCube = Reflection.getClass("mekanism.common.tileentity.TileEntityEnergyCube");

    @Override
    public Class<?> getTileEntityClass() {
        return TileentityEnergyCube;
    }
    @Override
    public ManagedEnvironment createEnvironment(final World world, final int x, final int y, final int z) {
        return new ManagedPeripheral((IPeripheral) world.getBlockTileEntity(x, y, z));
    }
}
