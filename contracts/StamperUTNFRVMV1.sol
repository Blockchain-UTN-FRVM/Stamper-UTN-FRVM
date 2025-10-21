    // SPDX-License-Identifier: MIT
    pragma solidity >=0.4.21 <0.6.0;

    contract StamperUTNFRVM {
        struct Stamp {
            bytes32 object;
            uint256 blockNo;
            uint256 timestamp;
            uint256 idUsuario; // Cambiado de string a uint256
        }
        
        Stamp[] private stampList; //Almacena lista de Stamps, cada uno con un hash, block number, timestamp y idUsuario
        mapping(bytes32 => uint256[]) private hashObjects; // Mapping que asocia hashes con sus posiciones en la lista de Stamps

        event Stamped(
            bytes32 indexed object,
            uint256 blockNo,
            uint256 timestamp,
            uint256 idUsuario
        );

        address private owner;
        mapping(address => bool) private authorizedAddresses;

        constructor() public {
            owner = msg.sender; // Establece el propietario del contrato como la dirección que lo despliega
        }
        //Permisos de acceso
        modifier onlyAuthorized() {
            require(msg.sender == owner || authorizedAddresses[msg.sender], "No tienes permiso para registrar hashes");
            _;
        }
        function authorizeAddress(address _address) public {
            require(msg.sender == owner, "Solo el propietario puede autorizar direcciones");
            authorizedAddresses[_address] = true;
        }

        function revokeAddress(address _address) public {
            require(msg.sender == owner, "Solo el propietario puede revocar direcciones");
            authorizedAddresses[_address] = false;
        }

        // Stampear una lista de hashes recibidos como array
        function postHash(bytes32[] memory objectList, uint256 idUsuario) public onlyAuthorized {
            for (uint256 i = 0; i < objectList.length; i++) {
                bytes32 object = objectList[i];
                stampList.push(Stamp(object, block.number, block.timestamp, idUsuario));
                uint256 newObjectIndex = stampList.length - 1;
                hashObjects[object].push(newObjectIndex);
                emit Stamped(object, block.number, block.timestamp, idUsuario);
            }
        }

        // Validar un hash específico y devolver todos los datos asociados
        function validateHash(bytes32 object) public view returns (bool, bytes32[] memory, uint256[] memory, uint256[] memory, uint256[] memory) {
            if (hashObjects[object].length > 0) {
                uint256 length = hashObjects[object].length;
                bytes32[] memory objects = new bytes32[](length);
                uint256[] memory blockNos = new uint256[](length);
                uint256[] memory timestamps = new uint256[](length);
                uint256[] memory idUsuarios = new uint256[](length);

                for (uint256 i = 0; i < length; i++) {
                    uint256 index = hashObjects[object][i];
                    Stamp storage stamp = stampList[index];
                    objects[i] = stamp.object;
                    blockNos[i] = stamp.blockNo;
                    timestamps[i] = stamp.timestamp;
                    idUsuarios[i] = stamp.idUsuario;
                }
                return (true, objects, blockNos, timestamps, idUsuarios);
            }
            return (false, new bytes32[](0), new uint256[](0), new uint256[](0), new uint256[](0));
        }
    }
