package li.cil.oc.server

import cpw.mods.fml.common.network.Player
import li.cil.oc.common.PacketType
import li.cil.oc.common.tileentity._
import li.cil.oc.common.{PacketHandler => CommonPacketHandler}
import net.minecraft.entity.player.EntityPlayer
import net.minecraftforge.common.DimensionManager
import scala.Some

class PacketHandler extends CommonPacketHandler {
  protected def world(player: Player, dimension: Int) =
    Option(DimensionManager.getWorld(dimension))

  def dispatch(p: PacketParser) =
    p.packetType match {
      case PacketType.ComputerPower => onComputerPower(p)
      case PacketType.KeyDown => onKeyDown(p)
      case PacketType.KeyUp => onKeyUp(p)
      case PacketType.Clipboard => onClipboard(p)
      case PacketType.MouseClickOrDrag => onMouseClick(p)
      case PacketType.MouseScroll => onMouseScroll(p)
      case _ => // Invalid packet.
    }

  def onComputerPower(p: PacketParser) =
    p.readTileEntity[TileEntity]() match {
      case Some(t: Computer) => p.player match {
        case player: EntityPlayer => trySetComputerPower(t.computer, p.readBoolean(), player)
        case _ =>
      }
      case Some(r: Rack) => r.servers(p.readInt()) match {
        case Some(server) => p.player match {
          case player: EntityPlayer => trySetComputerPower(server.machine, p.readBoolean(), player)
          case _ =>
        }
        case _ => // Invalid packet.
      }
      case _ => // Invalid packet.
    }

  private def trySetComputerPower(computer: component.Machine, value: Boolean, player: EntityPlayer) {
    if (computer.canInteract(player.getCommandSenderName)) {
      if (value) {
        if (!computer.isPaused) {
          computer.start()
          computer.lastError match {
            case Some(message) => player.addChatMessage(message)
            case _ =>
          }
        }
      }
      else computer.stop()
    }
  }

  def onKeyDown(p: PacketParser) =
    p.readTileEntity[Buffer]() match {
      case Some(s: Screen) =>
        val char = Char.box(p.readChar())
        val code = Int.box(p.readInt())
        s.screens.foreach(_.node.sendToNeighbors("keyboard.keyDown", p.player, char, code))
      case Some(e) => e.buffer.node.sendToNeighbors("keyboard.keyDown", p.player, Char.box(p.readChar()), Int.box(p.readInt()))
      case _ => // Invalid packet.
    }

  def onKeyUp(p: PacketParser) =
    p.readTileEntity[Buffer]() match {
      case Some(s: Screen) =>
        val char = Char.box(p.readChar())
        val code = Int.box(p.readInt())
        s.screens.foreach(_.node.sendToNeighbors("keyboard.keyUp", p.player, char, code))
      case Some(e) => e.buffer.node.sendToNeighbors("keyboard.keyUp", p.player, Char.box(p.readChar()), Int.box(p.readInt()))
      case _ => // Invalid packet.
    }

  def onClipboard(p: PacketParser) =
    p.readTileEntity[Buffer]() match {
      case Some(s: Screen) =>
        val value = p.readUTF()
        s.screens.foreach(_.node.sendToNeighbors("keyboard.clipboard", p.player, value))
      case Some(e) => e.buffer.node.sendToNeighbors("keyboard.clipboard", p.player, p.readUTF())
      case _ => // Invalid packet.
    }

  def onMouseClick(p: PacketParser) =
    p.readTileEntity[Buffer]() match {
      case Some(s: Screen) => p.player match {
        case player: EntityPlayer =>
          val x = p.readInt()
          val y = p.readInt()
          val what = if (p.readBoolean()) "drag" else "touch"
          s.origin.node.sendToReachable("computer.checked_signal", player, what, Int.box(x), Int.box(y), player.getCommandSenderName)
        case _ =>
      }
      case _ => // Invalid packet.
    }

  def onMouseScroll(p: PacketParser) =
    p.readTileEntity[Buffer]() match {
      case Some(s: Screen) => p.player match {
        case player: EntityPlayer =>
          val x = p.readInt()
          val y = p.readInt()
          val scroll = p.readByte()
          s.origin.node.sendToReachable("computer.checked_signal", player, "scroll", Int.box(x), Int.box(y), Int.box(scroll), player.getCommandSenderName)
        case _ =>
      }
      case _ => // Invalid packet.
    }
}