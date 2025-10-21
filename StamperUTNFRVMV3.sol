// SPDX-License-Identifier: MIT
pragma solidity >=0.4.21 <0.6.0;

contract StamperUTNFRVMV3 {
    struct Stamp {
        bytes32 hash;
        uint256 idUsuario;
        uint256 blockNo;
    }
    
    Stamp[] private stampList; //Almacena lista de Stamps, cada uno con un hash, block number, timestamp y idUsuario
    mapping(bytes32 => uint256[]) private hashObjects; // Mapping que asocia hashes con sus posiciones en la lista de Stamps

    event HashAlreadyStamped(
        bytes32 indexed hash, 
        uint256 indexed idUsuario);

    event Stamped(
        bytes32 indexed hash,
        uint256 indexed idUsuario,
        uint256 blockNo,
        address contractAddress
    );

    address private owner;
    mapping(address => bool) private authorizedAddresses;

    uint256 private hashListMaxLength = 100;

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

    function hashListLength(bytes32[] memory hashList) public view returns (bool) {
        if (hashList.length > 0 && hashList.length <= hashListMaxLength) {
            return true;
        }
        return false;
    }

    function sethashListMaxLength(uint256 newMax) public {
        require(msg.sender == owner, "Solo el propietario puede cambiar el maximo");
        hashListMaxLength = newMax;
    }

    // Stampear una lista de hashes recibidos como array
    function postHash(bytes32[] memory hashList, uint256 idUsuario) public onlyAuthorized returns (bytes32[] memory, bytes32[] memory) {
        require(hashListLength(hashList), "Tamaño de lista de hashes inválido");
        bytes32[] memory tempStamped = new bytes32[](hashList.length);
        bytes32[] memory tempAlready = new bytes32[](hashList.length);
        uint256 stampedCount = 0;
        uint256 alreadyCount = 0;
        for (uint256 i = 0; i < hashList.length; i++) {
            bytes32 hash = hashList[i];
            bool alreadyStamped = false;
            uint256[] storage users = hashObjects[hash];
            for (uint256 j = 0; j < users.length; j++) { //recorre los usuarios que ya stampearon el hash
                if (stampList[users[j]].idUsuario == idUsuario) {
                    alreadyStamped = true;
                    break;
                }
            }
            if (alreadyStamped) {
                tempAlready[alreadyCount] = hash;
                alreadyCount++;
                emit HashAlreadyStamped(hash, idUsuario);
                continue;
            } else {
                tempStamped[stampedCount] = hash;
                stampedCount++;
                stampList.push(Stamp(hash, idUsuario, block.number));
                uint256 newHashIndex = stampList.length - 1;
                hashObjects[hash].push(newHashIndex);
                emit Stamped(hash, idUsuario, block.number, address(this));
            }
        }
        bytes32[] memory hashesStamped = new bytes32[](stampedCount);
        for (uint256 i = 0; i < stampedCount; i++) {
            hashesStamped[i] = tempStamped[i];
        }
        bytes32[] memory hashesAlreadyStamped = new bytes32[](alreadyCount);
        for (uint256 i = 0; i < alreadyCount; i++) {
            hashesAlreadyStamped[i] = tempAlready[i];
        }
        return (hashesStamped, hashesAlreadyStamped);
    }

    // Validar un hash específico y devolver si existe, el hash, la lista de usuarios y la lista de block numbers
    function validateHash(bytes32 hash) public view returns (bool, bytes32, uint256[] memory, uint256[] memory, address) {
        uint256 length = hashObjects[hash].length;
        if (length > 0) {
            uint256[] memory idUsuarios = new uint256[](length);
            uint256[] memory blockNos = new uint256[](length);
            for (uint256 i = 0; i < length; i++) {
                uint256 index = hashObjects[hash][i];
                Stamp storage stamp = stampList[index];
                idUsuarios[i] = stamp.idUsuario;
                blockNos[i] = stamp.blockNo;
            }
            return (true, hash, idUsuarios, blockNos, address(this));
        }
        // Si no existe, devuelve false, hash vacío y arrays vacíos
        return (false, bytes32(0), new uint256[](0), new uint256[](0), address(this));
    }

    // Obtener todos los hashes registrados por un usuario
    function getHashesByUser(uint256 idUsuario) public view returns (bytes32[] memory, uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < stampList.length; i++) {
            if (stampList[i].idUsuario == idUsuario) {
                count++;
            }
        }
        bytes32[] memory hashes = new bytes32[](count);
        uint256[] memory blockNos = new uint256[](count);
        uint256 j = 0;
        for (uint256 i = 0; i < stampList.length; i++) {
            if (stampList[i].idUsuario == idUsuario) {
                hashes[j] = stampList[i].hash;
                blockNos[j] = stampList[i].blockNo;
                j++;
            }
        }
        return (hashes, blockNos);
    }
}
