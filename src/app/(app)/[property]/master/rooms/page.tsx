import { listRooms, listRoomTypes } from "@/features/master/queries";
import { RoomsManager } from "@/components/master/rooms-manager";

export default async function RoomsPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;
  const [rooms, roomTypes] = await Promise.all([
    listRooms(propertyId),
    listRoomTypes(propertyId),
  ]);

  return (
    <RoomsManager propertyId={propertyId} rooms={rooms} roomTypes={roomTypes} />
  );
}
