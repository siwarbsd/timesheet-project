package tn.esprit.spring.dto;

/**
 * DTO utilisé uniquement pour la création d'un User via l'API.
 * Ne contient que les champs nécessaires envoyés par le client.
 * Les champs sensibles ou générés (id, date, role) sont gérés côté serveur.
 */
public class UserCreateDTO {

    private String lastName;

    public UserCreateDTO() {
    }

    public UserCreateDTO(String lastName) {
        this.lastName = lastName;
    }

    public String getLastName() {
        return lastName;
    }

    public void setLastName(String lastName) {
        this.lastName = lastName;
    }
}
